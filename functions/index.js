const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const jwt = require("jsonwebtoken");

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
      for (const field of ["requesterId", "organizationId"]) {
        const snapshot = await db
            .collection("meetings")
            .where(field, "==", uid)
            .get();
        snapshot.docs.forEach((doc) => meetingIds.add(doc.id));
      }

      let meetings = 0;
      for (const ids of chunk([...meetingIds], 30)) {
        const batch = db.batch();
        ids.forEach((id) => batch.delete(db.collection("meetings").doc(id)));
        await batch.commit();
        meetings += ids.length;
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
