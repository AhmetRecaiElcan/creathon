/**
 * Tests for the invite gate — the part of admission that actually enforces it.
 *
 * The check in the signup screen only produces the message; a client that
 * skipped it would still land on these rules, so this is where the security
 * claim has to be proved. Run with:
 *
 *   cd firebase/rules_test && npm install && npm test
 */
import assert from "node:assert";
import { readFileSync } from "node:fs";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

const env = await initializeTestEnvironment({
  projectId: "creathon-test",
  firestore: {
    host: "127.0.0.1",
    port: 8085,
    rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
  },
});

/** A verified account, which every writing rule requires. */
const verified = (uid, email) =>
  env.authenticatedContext(uid, { email, email_verified: true }).firestore();

/** Seeds the guest list and the admin roster with the rules switched off. */
async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "invites/elif@example.com"), { role: "visitor" });
    await setDoc(doc(db, "invites/kurum@nexora.com"), { role: "corporate" });
    await setDoc(doc(db, "admins/panel-operator"), { note: "T3" });
  });
}

const tests = {
  "an invited visitor may create the profile the list granted": async () => {
    const db = verified("elif", "elif@example.com");
    await assertSucceeds(
      setDoc(doc(db, "users/elif"), { role: "visitor", email: "elif@example.com" }),
    );
  },

  "an invited visitor may not create an investor profile": async () => {
    // The whole feature in one assertion: the audience is the organiser's to
    // decide, and a client asking for a different one is refused by the server.
    const db = verified("elif", "elif@example.com");
    await assertFails(
      setDoc(doc(db, "users/elif"), { role: "investor", email: "elif@example.com" }),
    );
  },

  "an address on no list may not create a profile at all": async () => {
    const db = verified("yabanci", "yabanci@example.com");
    await assertFails(
      setDoc(doc(db, "users/yabanci"), { role: "visitor" }),
    );
  },

  "capitals on the token still match the lower-cased row": async () => {
    // The Dart side folds through Invite.idFor; the rule folds with .lower().
    // If these two ever disagree, an invited guest is refused at the door.
    const db = verified("elif2", "Elif@Example.com");
    await assertSucceeds(
      setDoc(doc(db, "users/elif2"), { role: "visitor" }),
    );
  },

  "the role is frozen after creation": async () => {
    const db = verified("elif3", "elif@example.com");
    await assertSucceeds(setDoc(doc(db, "users/elif3"), { role: "visitor" }));
    // Without the freeze, admission would be a formality: create what the list
    // allows, then rewrite the field.
    await assertFails(updateDoc(doc(db, "users/elif3"), { role: "investor" }));
    // Everything else about the profile stays editable.
    await assertSucceeds(updateDoc(doc(db, "users/elif3"), { firstName: "Elif" }));
  },

  "an unverified account is refused even when invited": async () => {
    const db = env
      .authenticatedContext("elif4", {
        email: "elif@example.com",
        email_verified: false,
      })
      .firestore();
    await assertFails(setDoc(doc(db, "users/elif4"), { role: "visitor" }));
  },

  "a card may only be published by an invited company or venture": async () => {
    // organizations is world-readable — it is the 3D hall and every scanned QR —
    // so an uninvited account must not be able to put a stand in it.
    const visitor = verified("elif5", "elif@example.com");
    await assertFails(setDoc(doc(visitor, "organizations/elif5"), { name: "Sahte" }));

    const company = verified("kurum", "kurum@nexora.com");
    await assertSucceeds(
      setDoc(doc(company, "organizations/kurum"), { name: "Nexora" }),
    );
  },

  "a guest reads their own row and nobody else's": async () => {
    const db = verified("elif6", "elif@example.com");
    await assertSucceeds(getDoc(doc(db, "invites/elif@example.com")));
    // The guest list is not browsable from a phone: who else is coming is
    // nobody's business.
    await assertFails(getDoc(doc(db, "invites/kurum@nexora.com")));
  },

  "only an admin writes the guest list": async () => {
    const guest = verified("elif7", "elif@example.com");
    await assertFails(
      setDoc(doc(guest, "invites/kendim@example.com"), { role: "investor" }),
    );

    const admin = verified("panel-operator", "panel@t3.org");
    await assertSucceeds(
      setDoc(doc(admin, "invites/yeni@example.com"), { role: "visitor" }),
    );
    await assertSucceeds(getDoc(doc(admin, "invites/elif@example.com")));
  },

  "the programme is world-readable but admin-written": async () => {
    // events reaches all four portfolios' home feeds at once, so an account
    // that could post to it could put a message on every phone at the event.
    const guest = verified("elif8", "elif@example.com");
    await assertFails(
      setDoc(doc(guest, "events/sahte"), { title: "Sahte oturum" }),
    );

    const admin = verified("panel-operator", "panel@t3.org");
    await assertSucceeds(
      setDoc(doc(admin, "events/acilis"), { title: "Açılış", venue: "Ana Sahne" }),
    );
    // Reads stay open: a visitor has to see the programme before they have an
    // account.
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), "events/acilis")));
  },

  "an admin can withdraw a session from the programme": async () => {
    const admin = verified("panel-operator", "panel@t3.org");
    await assertSucceeds(setDoc(doc(admin, "events/panel"), { title: "Panel" }));
    await assertSucceeds(deleteDoc(doc(admin, "events/panel")));

    const guest = verified("elif9", "elif@example.com");
    await assertSucceeds(setDoc(doc(admin, "events/kalsin"), { title: "Kalsın" }));
    await assertFails(deleteDoc(doc(guest, "events/kalsin")));
  },

  "either party may end a confirmed meeting, and only end it": async () => {
    const meeting = {
      requesterId: "yatirimci",
      organizationId: "kurum",
      status: "confirmed",
      mode: "online",
      roomName: "oda-1",
      start: "2026-08-25T12:00:00.000",
      end: "2026-08-25T12:30:00.000",
    };
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "meetings/m1"), meeting);
      await setDoc(doc(ctx.firestore(), "meetings/m2"), meeting);
    });

    // A meeting is over when one of the two people in it says so, and which of
    // them happened to host it has nothing to do with that.
    const requester = verified("yatirimci", "yatirimci@example.com");
    await assertSucceeds(
      updateDoc(doc(requester, "meetings/m1"), {status: "completed"}),
    );

    // The host could always do this; it must keep working.
    const host = verified("kurum", "kurum@nexora.com");
    await assertSucceeds(
      updateDoc(doc(host, "meetings/m2"), {status: "completed"}),
    );
  },

  "a requester cannot use the end button to rewrite the meeting": async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "meetings/m1"), {
        requesterId: "yatirimci",
        organizationId: "kurum",
        status: "confirmed",
        mode: "online",
        start: "2026-08-25T12:00:00.000",
        end: "2026-08-25T12:30:00.000",
      });
    });
    const requester = verified("yatirimci", "yatirimci@example.com");

    // `status` is the only key the new clause opens, so the room stays the
    // host's to name — otherwise a link could be slipped into a meeting the
    // host believes is a booth visit.
    await assertFails(
      updateDoc(doc(requester, "meetings/m1"), {roomName: "benim-odam"}),
    );
    await assertFails(
      updateDoc(doc(requester, "meetings/m1"), {
        status: "completed",
        roomName: "benim-odam",
      }),
    );
    // And `completed` is the only value: confirming their own request would
    // let a requester agree a meeting on the host's behalf.
    await assertFails(
      updateDoc(doc(requester, "meetings/m1"), {status: "confirmed"}),
    );
  },

  "a request nobody answered cannot be completed by the requester": async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "meetings/m1"), {
        requesterId: "yatirimci",
        organizationId: "kurum",
        status: "requested",
        start: "2026-08-25T12:00:00.000",
        end: "2026-08-25T12:30:00.000",
      });
    });
    // Without the "from confirmed" clause this would go through, and the
    // requester could rate a meeting that never happened.
    const requester = verified("yatirimci", "yatirimci@example.com");
    await assertFails(
      updateDoc(doc(requester, "meetings/m1"), {status: "completed"}),
    );
  },

  "a stranger cannot end somebody else's meeting": async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "meetings/m1"), {
        requesterId: "yatirimci",
        organizationId: "kurum",
        status: "confirmed",
        start: "2026-08-25T12:00:00.000",
        end: "2026-08-25T12:30:00.000",
      });
    });
    const stranger = verified("baskasi", "baskasi@example.com");
    await assertFails(
      updateDoc(doc(stranger, "meetings/m1"), {status: "completed"}),
    );
  },

  "nobody can grant themselves admin": async () => {
    // A collection that could grant its own membership would make the guest
    // list decorative, since an admin is what writes it.
    const db = verified("firsatci", "firsatci@example.com");
    await assertFails(setDoc(doc(db, "admins/firsatci"), { note: "ben" }));
    const admin = verified("panel-operator", "panel@t3.org");
    await assertFails(setDoc(doc(admin, "admins/arkadasim"), { note: "o da" }));
  },
};

let failed = 0;
for (const [name, run] of Object.entries(tests)) {
  await env.clearFirestore();
  await seed();
  try {
    await run();
    console.log(`  ok   ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`  FAIL ${name}\n       ${error.message}`);
  }
}

await env.cleanup();
console.log(
  failed === 0
    ? `\n${Object.keys(tests).length} kural testi geçti.`
    : `\n${failed} kural testi başarısız.`,
);
assert.equal(failed, 0);
