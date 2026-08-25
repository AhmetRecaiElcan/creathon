const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const jwt = require("jsonwebtoken");
const crypto = require("node:crypto");

initializeApp();

/**
 * The JaaS tenant. Public: it is the first path segment of every join URL, so
 * there is nothing to hide and a caller could read it off any link.
 */
const APP_ID = defineString("JAAS_APP_ID", {
  default: "vpaas-magic-cookie-27529844f95f4d0580ff59dc440d6a23",
});

/**
 * The API key's id, which travels in the JWT header as `kid` so 8x8 knows which
 * of the tenant's public keys to check the signature against.
 */
const KEY_ID = defineSecret("JAAS_KEY_ID");

/**
 * The RSA private key that signs the token. The whole reason this function
 * exists: put it in the app and anyone who unzips the APK can mint tokens
 * against the tenant for as long as the key lives.
 */
const PRIVATE_KEY = defineSecret("JAAS_PRIVATE_KEY");

/** Long enough to outlast a meeting that runs over, short enough to matter. */
const TOKEN_TTL_SECONDS = 3 * 60 * 60;

/**
 * Newlines do not survive every route into Secret Manager — a key piped from a
 * file arrives with a trailing one, and a key pasted into a prompt can arrive
 * with the breaks escaped. `jsonwebtoken` needs the real thing, and a stray
 * newline inside a JWT header is a token 8x8 rejects with nothing useful to
 * say, so both shapes are straightened out here rather than debugged later.
 */
function normalisePem(value) {
  const trimmed = value.trim();
  return trimmed.includes("\\n") ? trimmed.replace(/\\n/g, "\n") : trimmed;
}

/**
 * Issues a join link for a confirmed online meeting.
 *
 * The room name is not the security boundary — anyone holding a Jitsi URL can
 * walk in, which is exactly why the check happens here rather than in the app.
 * A token is minted only for an account that is one of the two parties to a
 * meeting that has actually been agreed, and it is scoped to that one room:
 * a `room: "*"` token would open every meeting in the tenant to whoever held
 * it.
 */
exports.meetingJoinLink = onCall(
    {
      region: "europe-west1",
      secrets: [KEY_ID, PRIVATE_KEY],
      cors: true,
    },
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError(
            "unauthenticated",
            "Görüşmeye katılmak için oturum açman gerekiyor.",
        );
      }

      const meetingId = request.data && request.data.meetingId;
      if (typeof meetingId !== "string" || meetingId.length === 0) {
        throw new HttpsError("invalid-argument", "Toplantı kimliği eksik.");
      }

      const snapshot = await getFirestore()
          .collection("meetings")
          .doc(meetingId)
          .get();

      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Toplantı bulunamadı.");
      }

      const meeting = snapshot.data();
      const uid = auth.uid;

      // Being a party to the meeting is the only thing that grants a token.
      // Not membership of the organisation, not knowing the room name.
      const isHost = meeting.organizationId === uid;
      const isRequester = meeting.requesterId === uid;
      if (!isHost && !isRequester) {
        throw new HttpsError(
            "permission-denied",
            "Bu toplantı sana ait değil.",
        );
      }

      if (meeting.status !== "confirmed") {
        throw new HttpsError(
            "failed-precondition",
            "Toplantı henüz onaylanmadı.",
        );
      }
      if (meeting.mode !== "online") {
        throw new HttpsError(
            "failed-precondition",
            "Bu toplantı yüz yüze yapılacak.",
        );
      }

      const room = meeting.roomName;
      if (typeof room !== "string" || room.length === 0) {
        throw new HttpsError(
            "failed-precondition",
            "Toplantının görüşme odası yok.",
        );
      }

      // Whichever side is calling, the name the *other* one will see.
      const name = isHost ?
        meeting.organizationName :
        meeting.requesterName;

      const now = Math.floor(Date.now() / 1000);
      const appId = APP_ID.value();

      const token = jwt.sign(
          {
            aud: "jitsi",
            iss: "chat",
            sub: appId,
            room,
            // Clock skew between here and 8x8 would otherwise reject a token
            // that is only a second old.
            nbf: now - 10,
            exp: now + TOKEN_TTL_SECONDS,
            context: {
              user: {
                id: uid,
                name,
                email: auth.token.email || "",
                avatar: "",
                // Both parties, deliberately. A two-person meeting where only
                // one side is a moderator is a meeting where one side sits in
                // a lobby waiting for the other to show up first — which is
                // the whole problem we left the public instance to escape.
                moderator: "true",
              },
              features: {
                livestreaming: "false",
                recording: "false",
                transcription: "false",
                "outbound-call": "false",
              },
            },
          },
          normalisePem(PRIVATE_KEY.value()),
          {algorithm: "RS256", header: {kid: KEY_ID.value().trim()}},
      );

      return {
        url: `https://8x8.vc/${appId}/${room}?jwt=${token}`,
        expiresAt: (now + TOKEN_TTL_SECONDS) * 1000,
      };
    },
);

/** The panel's region, matching every other callable in this file. */
const REGION = "europe-west1";

/**
 * Confirms the caller runs the admin panel.
 *
 * Membership is a Firestore document nobody can write — the rules close
 * `admins` to every client — so the only way one appears is the Firebase
 * console. Read here rather than trusted from a custom claim for the same
 * reason the panel checks it: this function bypasses security rules entirely,
 * so it has to do its own door.
 */
async function requireAdmin(auth) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Oturum açman gerekiyor.");
  }
  const doc = await getFirestore().collection("admins").doc(auth.uid).get();
  if (!doc.exists) {
    throw new HttpsError("permission-denied", "Bu hesap yönetici değil.");
  }
  return auth.uid;
}

/**
 * Deletes every document a query matches, in batches.
 *
 * Firestore caps a batch at 500 writes, and a fair's worth of meetings can
 * exceed that for a busy exhibitor — so this pages rather than assuming the
 * result set is small. Returns how many went, because the panel reports the
 * teardown back to the operator and "done" with no numbers is not something an
 * organiser can check.
 */
async function deleteMatching(query) {
  const db = getFirestore();
  let removed = 0;
  for (;;) {
    const snapshot = await query.limit(400).get();
    if (snapshot.empty) return removed;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    removed += snapshot.size;
    if (snapshot.size < 400) return removed;
  }
}

/** Firestore's `in` filter takes at most 30 values, so chunk the ids. */
function chunk(values, size) {
  const chunks = [];
  for (let i = 0; i < values.length; i += size) {
    chunks.push(values.slice(i, i + size));
  }
  return chunks;
}

/**
 * Removes an account and everything keyed to it.
 *
 * Deleting a user from the Firebase console reaches Auth and nothing else: the
 * card stays published, the booth stays coloured in the 3D hall for a company
 * that no longer exists, and the meetings stay booked against slots nobody can
 * free — the rules let only the two parties touch a request, so one left
 * behind is unreachable forever. That is the whole reason this exists.
 *
 * The order is data first, account last, matching the app's own teardown in
 * `AccountDeletion`. Reversed, a failure halfway through would leave documents
 * whose owner is already gone, which is precisely the mess being cleaned up.
 */
exports.adminDeleteAccount = onCall(
    {region: REGION, cors: true},
    async (request) => {
      const callerUid = await requireAdmin(request.auth);

      const uid = request.data && request.data.uid;
      if (typeof uid !== "string" || uid.length === 0) {
        throw new HttpsError("invalid-argument", "Hesap kimliği eksik.");
      }

      const db = getFirestore();

      // An operator must not be able to delete the panel's way in — their own
      // account or a colleague's. Locking every admin out of the panel is not
      // recoverable from the panel, and the console is the only way back.
      if (uid === callerUid) {
        throw new HttpsError(
            "failed-precondition",
            "Kendi yönetici hesabını buradan silemezsin.",
        );
      }
      if ((await db.collection("admins").doc(uid).get()).exists) {
        throw new HttpsError(
            "failed-precondition",
            "Bu hesap yönetici. Önce konsoldan admins kaydını sil.",
        );
      }

      // Meetings first, and both sides of them: this account is the requester
      // on some and the host on others.
      const meetingIds = new Set();
      // Both sides of each meeting, kept because the AI briefing below is
      // per-viewer: the counterpart holds one too, and its uid is only
      // knowable from the record that is about to be deleted.
      const meetingOwners = {};
      for (const field of ["requesterId", "organizationId"]) {
        const snapshot = await db
            .collection("meetings")
            .where(field, "==", uid)
            .get();
        snapshot.docs.forEach((doc) => {
          meetingIds.add(doc.id);
          const data = doc.data();
          meetingOwners[doc.id] = {
            requesterId: data.requesterId,
            organizationId: data.organizationId,
          };
        });
      }

      let meetings = 0;
      for (const ids of chunk([...meetingIds], 30)) {
        const batch = db.batch();
        ids.forEach((id) => batch.delete(db.collection("meetings").doc(id)));
        await batch.commit();
        meetings += ids.length;
      }

      // The AI's caches go with the things they describe. Neither is reachable
      // from any screen once its subject is gone — a ranking for a deleted
      // account, a briefing for a deleted meeting — so leaving them behind is
      // exactly the litter this function exists to sweep. Keyed by document id
      // rather than queried: the ranking is one doc per account, and a briefing
      // is `{meetingId}__{uid}` for each of the meeting's two sides.
      await db.collection("aiMatches").doc(uid).delete();
      for (const ids of chunk([...meetingIds], 30)) {
        const batch = db.batch();
        for (const id of ids) {
          batch.delete(db.collection("meetingBriefs").doc(`${id}__${uid}`));
          // The counterpart's briefing for the same meeting. Their uid is on
          // the record, and the meeting it belongs to is about to not exist.
          for (const field of ["requesterId", "organizationId"]) {
            const other = (meetingOwners[id] || {})[field];
            if (other && other !== uid) {
              batch.delete(
                  db.collection("meetingBriefs").doc(`${id}__${other}`),
              );
            }
          }
        }
        await batch.commit();
      }

      // Ratings for those meetings, from *either* side. Querying by authorId
      // alone would miss the counterpart's row: its authorId and organizationId
      // both belong to the other party, so nothing about it names this account
      // except the meeting it is attached to.
      let feedback = 0;
      for (const ids of chunk([...meetingIds], 30)) {
        feedback += await deleteMatching(
            db.collection("meetingFeedback").where("meetingId", "in", ids),
        );
      }
      // Strays: a rating whose meeting was already gone before this ran.
      feedback += await deleteMatching(
          db.collection("meetingFeedback").where("authorId", "==", uid),
      );

      // The booth lock and the card go together — the floor plan derives
      // occupancy from the card, so a lock left behind would hold a code that
      // nothing can claim and nothing displays.
      const stands = await deleteMatching(
          db.collection("stands").where("orgId", "==", uid),
      );
      // The card is keyed by the uid, so it is a delete rather than a query.
      const cardRef = db.collection("organizations").doc(uid);
      const hadCard = (await cardRef.get()).exists;
      if (hadCard) await cardRef.delete();

      await db.collection("users").doc(uid).delete();

      // Last, and tolerant of already being gone: an account the console
      // deleted earlier is exactly the leftover this function is here to clear,
      // and refusing at the final step would leave the documents behind again.
      let authDeleted = true;
      try {
        await getAuth().deleteUser(uid);
      } catch (error) {
        if (error.code === "auth/user-not-found") {
          authDeleted = false;
        } else {
          throw new HttpsError(
              "internal",
              `Hesap silinemedi: ${error.message}`,
          );
        }
      }

      // The guest list is deliberately untouched. Removing an account and
      // withdrawing an invitation are different intents — a person whose
      // account is deleted by mistake should be able to sign up again — and the
      // panel has a separate button for the invitation.
      return {meetings, feedback, stands, hadCard, authDeleted};
    },
);

/* ─────────────────────────── Yapay zekâ eşleştirme ─────────────────────────
 *
 * Sıralamanın "neden" kısmını üreten taraf. Uygulamadaki CardMatcher üç
 * etikete bakıp ağırlıklı puan verir — hızlı, açıklanabilir, ama kartın
 * anlattığı işi hiç okumaz: "otonom sürüş için LIDAR üretiyoruz" ile "filo
 * yönetimi SaaS" ikisi de Mobilite etiketi taşır ve deterministik puanlayıcı
 * için aynı şeydir. Buradaki model tam olarak o boşluğu doldurur.
 */

/**
 * The Gemini key.
 *
 * A secret rather than a parameter for the same reason the JaaS private key is
 * one: a key compiled into the app is a key anyone who unzips the APK can spend
 * against this project's quota. The model call lives here so the only thing the
 * client ever sees is the ranking.
 */
const GEMINI_KEY = defineSecret("GEMINI_API_KEY");

/**
 * Cheapest model in the family that still honours a response schema.
 *
 * Flash-Lite is picked deliberately: the job is scoring forty short cards
 * against one profile, which is reading comprehension rather than reasoning,
 * and it runs on every home screen open. Thinking is off by default on this
 * model, which is what keeps a rank cheap enough to do per session.
 */
const GEMINI_MODEL = "gemini-2.5-flash-lite";

/** Beyond this the prompt costs more than the ranking is worth. */
const MAX_CANDIDATES = 40;

/** Enough of a card to judge it; the rest is boilerplate. */
const MAX_DESCRIPTION = 420;

/**
 * How the model is briefed.
 *
 * Turkish because every string it produces is read in Turkish, and translating
 * a one-line rationale after the fact loses exactly the concrete detail that
 * makes it worth showing.
 */
const SYSTEM_PROMPT = [
  "Sen Take Off Girişim Zirvesi'nin eşleştirme motorusun. Elinde bir",
  "katılımcının profili ve fuarda kartını yayına almış kurum/girişim listesi",
  "var. Her kart için, bu katılımcının o kurumla görüşmesinin ne kadar değerli",
  "olduğunu 0-100 arası bir tam sayıyla puanla.",
  "",
  "Kurallar:",
  "- Puan gerekçeye dayanmalı. 85 ve üzeri, alan uyuşmasının yanında aşama veya",
  "  hedef pazarın da tutması ve kartın anlattığı işin katılımcının aradığı",
  "  şeyle gerçekten örtüşmesi anlamına gelir. 40'ın altı 'görüşmek için somut",
  "  bir sebep yok' demektir.",
  "- Etiketlere değil, kartın kendi açıklamasına bak. Aynı sektör etiketini",
  "  taşıyan iki kart bambaşka işler yapıyor olabilir; puanı ayıran şey bu",
  "  olmalı.",
  "- 'reason' tek bir Türkçe cümle olacak, en fazla 95 karakter, ve karttaki",
  "  somut bir bilgiye dayanacak. Kartta yazmayan hiçbir şeyi uydurma.",
  "- 'headline' en fazla 3 kelimelik Türkçe bir etiket: eşleşmenin en güçlü",
  "  sebebi. Örnek: 'Savunma · Seed uyumu'.",
  "- Listedeki her kart çıktıda tam olarak bir kez yer alacak, 'id' alanı sana",
  "  verilen değerin aynısı olacak.",
].join("\n");

/** Response shape the model is bound to, so nothing has to be parsed loosely. */
const MATCH_SCHEMA = {
  type: "OBJECT",
  properties: {
    matches: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          id: {type: "STRING"},
          score: {type: "INTEGER"},
          headline: {type: "STRING"},
          reason: {type: "STRING"},
        },
        required: ["id", "score", "headline", "reason"],
      },
    },
  },
  required: ["matches"],
};

/** The viewer, reduced to what actually decides a pairing. */
function viewerBrief(profile) {
  return {
    rol: profile.role || "visitor",
    fon: profile.companyName || null,
    yatirimciTipi: profile.investorKind || null,
    ilgiAlanlari: Array.isArray(profile.sectors) ? profile.sectors : [],
    aradigiAsamalar: Array.isArray(profile.stages) ? profile.stages : [],
    hedefPazarlar: Array.isArray(profile.markets) ? profile.markets : [],
  };
}

/** One card, trimmed to the fields the model is allowed to reason over. */
function cardBrief(doc) {
  const data = doc.data();
  const description = (data.description || "").trim();
  return {
    id: doc.id,
    tur: data.kind === "startup" ? "girişim" : "kurum",
    ad: (data.name || "").trim(),
    alan: data.sector || null,
    asama: data.stage || null,
    hedefPazar: data.market || null,
    aciklama: description.length > MAX_DESCRIPTION ?
      description.slice(0, MAX_DESCRIPTION) + "…" :
      description,
  };
}

/**
 * A key that changes exactly when the ranking would.
 *
 * The whole prompt hashed, so editing a card's description or adding a sector
 * to the profile invalidates the cache and nothing else does. Without this the
 * home screen would pay for a model call on every cold start, for an answer
 * that had not changed since the last one.
 */
function matchSignature(viewer, cards) {
  return crypto
      .createHash("sha1")
      .update(JSON.stringify({v: viewer, c: cards, m: GEMINI_MODEL}))
      .digest("hex");
}

/** Calls Gemini and returns the parsed `matches` array. */
async function rankWithGemini(viewer, cards, apiKey) {
  const url = "https://generativelanguage.googleapis.com/v1beta/models/" +
    GEMINI_MODEL + ":generateContent";

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      systemInstruction: {parts: [{text: SYSTEM_PROMPT}]},
      contents: [
        {
          role: "user",
          parts: [
            {text: JSON.stringify({katilimci: viewer, kartlar: cards})},
          ],
        },
      ],
      generationConfig: {
        // Low rather than zero: the same profile scored twice should land on
        // the same number, but a hard zero makes the model repeat one phrasing
        // for every card and the rationales stop being worth reading.
        temperature: 0.2,
        responseMimeType: "application/json",
        responseSchema: MATCH_SCHEMA,
      },
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new HttpsError(
        "unavailable",
        "Gemini isteği reddedildi (" + response.status + "): " +
          detail.slice(0, 300),
    );
  }

  const payload = await response.json();
  const candidate = payload &&
    Array.isArray(payload.candidates) &&
    payload.candidates[0];
  const part = candidate &&
    candidate.content &&
    Array.isArray(candidate.content.parts) &&
    candidate.content.parts[0];
  const text = part && part.text;

  if (typeof text !== "string") {
    throw new HttpsError("internal", "Model boş yanıt döndürdü.");
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    throw new HttpsError("internal", "Model yanıtı okunamadı.");
  }

  const known = new Set(cards.map((card) => card.id));
  const seen = new Set();
  const matches = [];

  for (const row of Array.isArray(parsed.matches) ? parsed.matches : []) {
    // A hallucinated id would render as a match against a card that is not on
    // the floor, so unknown and duplicate rows are dropped rather than trusted.
    if (!row || typeof row.id !== "string") continue;
    if (!known.has(row.id) || seen.has(row.id)) continue;
    seen.add(row.id);
    matches.push({
      id: row.id,
      score: Math.max(0, Math.min(100, Math.round(Number(row.score) || 0))),
      headline: String(row.headline || "").trim().slice(0, 40),
      reason: String(row.reason || "").trim().slice(0, 160),
    });
  }

  return matches;
}

/**
 * Ranks the published cards for whoever is calling.
 *
 * Takes no arguments on purpose. The profile and the cards are read here with
 * the admin SDK rather than accepted from the client, so a caller cannot spend
 * the project's model quota on a payload of its own invention, and cannot ask
 * for someone else's ranking either — the uid comes from the verified token.
 *
 * Falling back is the *app's* job, not this function's: a refusal here is
 * reported honestly and `AiMatchRepository` drops to CardMatcher, so a fair
 * with no internet still has a ranked hall.
 */
exports.aiMatch = onCall(
    {region: REGION, secrets: [GEMINI_KEY], cors: true},
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum açman gerekiyor.");
      }

      const apiKey = GEMINI_KEY.value().trim();
      if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "Yapay zekâ anahtarı tanımlı değil.",
        );
      }

      const db = getFirestore();
      const uid = auth.uid;

      const profileDoc = await db.collection("users").doc(uid).get();
      if (!profileDoc.exists) {
        throw new HttpsError("failed-precondition", "Profil bulunamadı.");
      }
      const viewer = viewerBrief(profileDoc.data());

      const snapshot = await db.collection("organizations").get();
      const cards = snapshot.docs
          // Nobody needs to be told how well they match themselves.
          .filter((doc) => doc.id !== uid)
          .map(cardBrief)
          .filter((card) => card.ad.length > 0)
          // Stable order so two calls over the same floor hash the same.
          .sort((a, b) => (a.id < b.id ? -1 : 1))
          .slice(0, MAX_CANDIDATES);

      if (cards.length === 0) {
        return {matches: [], model: GEMINI_MODEL, cached: false};
      }

      const signature = matchSignature(viewer, cards);
      const cacheRef = db.collection("aiMatches").doc(uid);
      const cached = await cacheRef.get();

      if (cached.exists && cached.data().signature === signature) {
        return {
          matches: cached.data().matches || [],
          model: cached.data().model || GEMINI_MODEL,
          cached: true,
        };
      }

      const matches = await rankWithGemini(viewer, cards, apiKey);

      // Written after the call rather than before, so a failed generation
      // leaves the previous good ranking in place to be served next time.
      await cacheRef.set({
        signature,
        matches,
        model: GEMINI_MODEL,
        updatedAt: new Date().toISOString(),
      });

      return {matches, model: GEMINI_MODEL, cached: false};
    },
);

/* ─────────────────────────── Görüşme brifingi ──────────────────────────────
 *
 * Eşleştirme "kiminle görüşmeliyim" sorusunu cevaplıyor. Bu, ondan sonra gelen
 * soruyu cevaplıyor: onaylanmış bir görüşmeye ne sorarak gireceğim. Fuarda
 * yarım saatlik bir slot, hazırlıksız girildiğinde iki tarafın da birbirine
 * kendini tanıttığı ve sonra bittiği bir slottur.
 */

/**
 * Enough of a card or a profile to brief someone on it.
 *
 * Read from Firestore rather than taken from the meeting record, because the
 * record deliberately only carries what an *agenda row* needs — names, the
 * fund, the hour. What the two sides actually do is on their card, and that is
 * the only thing worth briefing on.
 */
async function partyBrief(db, uid, fallbackName) {
  const [profileSnap, cardSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("organizations").doc(uid).get(),
  ]);

  const profile = profileSnap.exists ? profileSnap.data() : {};
  const card = cardSnap.exists ? cardSnap.data() : null;

  const brief = {
    ad: (card && card.name) || fallbackName || "",
    rol: profile.role || null,
    fon: profile.companyName || null,
    yatirimciTipi: profile.investorKind || null,
    ilgiAlanlari: Array.isArray(profile.sectors) ? profile.sectors : [],
    aradigiAsamalar: Array.isArray(profile.stages) ? profile.stages : [],
    hedefPazarlar: Array.isArray(profile.markets) ? profile.markets : [],
  };

  // A side with no published card is not a gap to be filled in — it is an
  // investor, and saying so is more useful than an empty description field.
  if (card) {
    const description = (card.description || "").trim();
    brief.kart = {
      tur: card.kind === "startup" ? "girişim" : "kurum",
      alan: card.sector || null,
      asama: card.stage || null,
      hedefPazar: card.market || null,
      aciklama: description.length > MAX_DESCRIPTION ?
        description.slice(0, MAX_DESCRIPTION) + "…" :
        description,
    };
  }

  return brief;
}

/** How the model is briefed for a briefing. */
const BRIEF_PROMPT = [
  "Sen Take Off Girişim Zirvesi'nde bir katılımcının görüşme hazırlığını yapan",
  "asistansın. Elinde onaylanmış bir görüşmenin iki tarafının profili var.",
  "'ben' alanı brifingi okuyacak kişi, 'karsiTaraf' ise görüşeceği kişi.",
  "",
  "Kurallar:",
  "- Her şeyi 'ben' alanındaki kişiye, ikinci tekil şahısla (sen) yaz.",
  "- 'why': bu yarım saatin neden değerli olduğunu söyleyen tek cümle. İki",
  "  tarafın verilerindeki somut bir örtüşmeye dayanmalı.",
  "- 'questions': tam üç soru. Genel değil, spesifik: karşı tarafın kartında",
  "  yazan işe dair, cevabı görüşmeden sonra bir karar vermeye yarayacak",
  "  sorular. 'Neler yapıyorsunuz' gibi bir soru kabul edilemez — o cevap",
  "  zaten elinde.",
  "- 'theirAsk': karşı tarafın senden büyük olasılıkla ne isteyeceği, tek",
  "  cümle. Rollerinden ve hedeflerinden çıkar.",
  "- 'prep': görüşmeye girmeden önce elinin altında olması gereken tek somut",
  "  şey. Tek cümle, uygulanabilir.",
  "- Verilerde olmayan hiçbir şeyi uydurma. Karşı tarafın kartı boşsa bunu",
  "  varsayımla doldurmak yerine, o boşluğu kapatan bir soru sor.",
  "- Türkçe yaz. Kısa yaz: her alan en fazla iki satır.",
].join("\n");

const BRIEF_SCHEMA = {
  type: "OBJECT",
  properties: {
    why: {type: "STRING"},
    questions: {type: "ARRAY", items: {type: "STRING"}},
    theirAsk: {type: "STRING"},
    prep: {type: "STRING"},
  },
  required: ["why", "questions", "theirAsk", "prep"],
};

/** Calls Gemini and returns the parsed brief. */
async function briefWithGemini(payload, apiKey) {
  const url = "https://generativelanguage.googleapis.com/v1beta/models/" +
    GEMINI_MODEL + ":generateContent";

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      systemInstruction: {parts: [{text: BRIEF_PROMPT}]},
      contents: [{role: "user", parts: [{text: JSON.stringify(payload)}]}],
      generationConfig: {
        // Warmer than the ranking's 0.2: three questions at near-zero
        // temperature come out as three rephrasings of one question, and the
        // whole value here is that they open three different conversations.
        temperature: 0.55,
        responseMimeType: "application/json",
        responseSchema: BRIEF_SCHEMA,
      },
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new HttpsError(
        "unavailable",
        "Gemini isteği reddedildi (" + response.status + "): " +
          detail.slice(0, 300),
    );
  }

  const payloadJson = await response.json();
  const candidate = payloadJson &&
    Array.isArray(payloadJson.candidates) &&
    payloadJson.candidates[0];
  const part = candidate &&
    candidate.content &&
    Array.isArray(candidate.content.parts) &&
    candidate.content.parts[0];
  const text = part && part.text;

  if (typeof text !== "string") {
    throw new HttpsError("internal", "Model boş yanıt döndürdü.");
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    throw new HttpsError("internal", "Model yanıtı okunamadı.");
  }

  const questions = (Array.isArray(parsed.questions) ? parsed.questions : [])
      .filter((question) => typeof question === "string" && question.trim())
      .map((question) => question.trim().slice(0, 240))
      // Three is what the prompt asks for; a model that returns five is not an
      // error worth failing on, but the sheet is laid out for three.
      .slice(0, 3);

  if (questions.length === 0) {
    throw new HttpsError("internal", "Brifing boş döndü.");
  }

  return {
    why: String(parsed.why || "").trim().slice(0, 300),
    questions,
    theirAsk: String(parsed.theirAsk || "").trim().slice(0, 300),
    prep: String(parsed.prep || "").trim().slice(0, 300),
  };
}

/**
 * Prepares whoever is calling for a meeting they have already agreed to.
 *
 * Per viewer, not per meeting: the same half-hour is a different briefing for
 * each side — one of them is being asked for money and the other is deciding
 * whether to write a cheque — so the cache is keyed by both.
 *
 * Only a confirmed meeting, and only for its two parties. Not a privacy nicety:
 * the brief is assembled from both sides' cards and profiles, so anyone who
 * could call this for a meeting they are not in would be reading a stranger's
 * thesis with the model as the go-between.
 */
exports.meetingBrief = onCall(
    {region: REGION, secrets: [GEMINI_KEY], cors: true},
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum açman gerekiyor.");
      }

      const apiKey = GEMINI_KEY.value().trim();
      if (!apiKey) {
        throw new HttpsError(
            "failed-precondition",
            "Yapay zekâ anahtarı tanımlı değil.",
        );
      }

      const meetingId = request.data && request.data.meetingId;
      if (typeof meetingId !== "string" || meetingId.length === 0) {
        throw new HttpsError("invalid-argument", "Toplantı kimliği eksik.");
      }

      const db = getFirestore();
      const uid = auth.uid;

      const snapshot = await db.collection("meetings").doc(meetingId).get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Toplantı bulunamadı.");
      }

      const meeting = snapshot.data();
      const isHost = meeting.organizationId === uid;
      const isRequester = meeting.requesterId === uid;
      if (!isHost && !isRequester) {
        throw new HttpsError("permission-denied", "Bu toplantı sana ait değil.");
      }
      if (meeting.status !== "confirmed") {
        throw new HttpsError(
            "failed-precondition",
            "Brifing yalnızca onaylanmış görüşmeler için hazırlanır.",
        );
      }

      const otherUid = isHost ? meeting.requesterId : meeting.organizationId;
      const [me, them] = await Promise.all([
        partyBrief(
            db,
            uid,
            isHost ? meeting.organizationName : meeting.requesterName,
        ),
        partyBrief(
            db,
            otherUid,
            isHost ? meeting.requesterName : meeting.organizationName,
        ),
      ]);

      const payload = {
        ben: me,
        karsiTaraf: them,
        gorusme: {
          bicim: meeting.mode === "online" ? "online" : "yüz yüze",
          yer: meeting.location || null,
          // The message the requester sent with the ask. Often the single most
          // informative field in the whole payload: it is the one place
          // somebody said, in their own words, what they want out of the hour.
          not: meeting.note || null,
        },
      };

      const signature = crypto
          .createHash("sha1")
          .update(JSON.stringify({p: payload, m: GEMINI_MODEL}))
          .digest("hex");

      const cacheRef = db
          .collection("meetingBriefs")
          .doc(meetingId + "__" + uid);
      const cached = await cacheRef.get();

      if (cached.exists && cached.data().signature === signature) {
        return {
          brief: cached.data().brief,
          model: cached.data().model || GEMINI_MODEL,
          cached: true,
        };
      }

      const brief = await briefWithGemini(payload, apiKey);

      await cacheRef.set({
        signature,
        brief,
        model: GEMINI_MODEL,
        updatedAt: new Date().toISOString(),
      });

      return {brief, model: GEMINI_MODEL, cached: false};
    },
);
