import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ROLES, isAdminRole } from "./roles";
import {
  REVIEWER_REQUESTS_COLLECTION,
  REQUEST_STATUS_APPROVED,
  REQUEST_STATUS_PENDING,
  REQUEST_STATUS_REJECTED,
} from "./schema";

admin.initializeApp();
const db = admin.firestore();

/**
 * Every callable here requires a signed-in caller whose users/{uid}
 * profile.role is clinicalAdmin — read straight from Firestore with the
 * Admin SDK (bypasses client rules, which is the point: this is the one
 * legitimate path to grant a protected role, per firestore.rules'
 * "Protected roles ... console / Admin SDK only" comment).
 */
async function requireClinicalAdmin(uid: string | undefined): Promise<void> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const snap = await db.collection("users").doc(uid).get();
  const role = snap.data()?.profile?.role;
  if (!isAdminRole(role)) {
    throw new HttpsError(
      "permission-denied",
      "Only a clinicalAdmin can perform this action.",
    );
  }
}

/**
 * Callable by ANY signed-in user: records that they want clinicalReviewer
 * access. Does not grant anything by itself — it just creates a pending
 * request an admin can see in the portal's Reviewers tab and act on.
 */
export const requestReviewerAccess = onCall(
  { region: "us-central1" },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const email = auth.token.email;
    if (!email) {
      throw new HttpsError(
        "failed-precondition",
        "Your account has no email on file; reviewer access requires one.",
      );
    }
    const note = typeof request.data?.note === "string"
      ? request.data.note.trim().slice(0, 500)
      : null;

    // One open (pending) request per uid — re-requesting updates it instead
    // of piling up duplicates.
    const existing = await db
      .collection(REVIEWER_REQUESTS_COLLECTION)
      .where("uid", "==", auth.uid)
      .where("status", "==", REQUEST_STATUS_PENDING)
      .limit(1)
      .get();

    const payload = {
      email,
      uid: auth.uid,
      displayName: auth.token.name ?? null,
      note,
      status: REQUEST_STATUS_PENDING,
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      decidedBy: null,
      decidedAt: null,
      decisionNote: null,
    };

    if (!existing.empty) {
      await existing.docs[0].ref.set(payload, { merge: true });
      return { id: existing.docs[0].id, status: "updated" };
    }
    const ref = await db.collection(REVIEWER_REQUESTS_COLLECTION).add(payload);
    return { id: ref.id, status: "created" };
  },
);

/**
 * clinicalAdmin-only: approve a pending reviewer-access request. Sets the
 * requester's users/{uid}.profile.role to clinicalReviewer and marks the
 * request approved. This is the only server path that writes a protected
 * role — see requireClinicalAdmin() above.
 */
export const approveClinicalReviewer = onCall(
  { region: "us-central1" },
  async (request) => {
    await requireClinicalAdmin(request.auth?.uid);
    const requestId = request.data?.requestId;
    if (typeof requestId !== "string" || requestId.trim().length === 0) {
      throw new HttpsError("invalid-argument", "requestId is required.");
    }

    const reqRef = db.collection(REVIEWER_REQUESTS_COLLECTION).doc(requestId);
    const reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }
    const data = reqSnap.data()!;
    if (data.status !== REQUEST_STATUS_PENDING) {
      throw new HttpsError(
        "failed-precondition",
        `Request is already ${data.status}.`,
      );
    }
    const targetUid: string = data.uid;
    if (!targetUid) {
      throw new HttpsError("failed-precondition", "Request has no uid.");
    }

    const adminEmail = request.auth!.token.email ?? request.auth!.uid;
    const userRef = db.collection("users").doc(targetUid);

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      const existingProfile = userSnap.data()?.profile ?? {};
      tx.set(
        userRef,
        { profile: { ...existingProfile, role: ROLES.clinicalReviewer } },
        { merge: true },
      );
      tx.update(reqRef, {
        status: REQUEST_STATUS_APPROVED,
        decidedBy: adminEmail,
        decidedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { uid: targetUid, role: ROLES.clinicalReviewer };
  },
);

/** clinicalAdmin-only: reject a pending reviewer-access request. Grants
 * nothing; just records the decision so it drops off the pending list. */
export const rejectReviewerAccess = onCall(
  { region: "us-central1" },
  async (request) => {
    await requireClinicalAdmin(request.auth?.uid);
    const requestId = request.data?.requestId;
    if (typeof requestId !== "string" || requestId.trim().length === 0) {
      throw new HttpsError("invalid-argument", "requestId is required.");
    }
    const note = typeof request.data?.note === "string"
      ? request.data.note.trim().slice(0, 500)
      : null;

    const reqRef = db.collection(REVIEWER_REQUESTS_COLLECTION).doc(requestId);
    const reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw new HttpsError("not-found", "Request not found.");
    }
    if (reqSnap.data()!.status !== REQUEST_STATUS_PENDING) {
      throw new HttpsError(
        "failed-precondition",
        `Request is already ${reqSnap.data()!.status}.`,
      );
    }
    const adminEmail = request.auth!.token.email ?? request.auth!.uid;
    await reqRef.update({
      status: REQUEST_STATUS_REJECTED,
      decidedBy: adminEmail,
      decidedAt: admin.firestore.FieldValue.serverTimestamp(),
      decisionNote: note,
    });
    return { status: REQUEST_STATUS_REJECTED };
  },
);

/**
 * clinicalAdmin-only: revoke an existing clinicalReviewer's access,
 * demoting them back to `patient`. (clinicalAdmin accounts cannot be
 * revoked through this function — do that in the console deliberately.)
 */
export const revokeClinicalReviewer = onCall(
  { region: "us-central1" },
  async (request) => {
    await requireClinicalAdmin(request.auth?.uid);
    const targetUid = request.data?.uid;
    if (typeof targetUid !== "string" || targetUid.trim().length === 0) {
      throw new HttpsError("invalid-argument", "uid is required.");
    }
    const userRef = db.collection("users").doc(targetUid);
    const snap = await userRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "User not found.");
    }
    const currentRole = snap.data()?.profile?.role;
    if (isAdminRole(currentRole)) {
      throw new HttpsError(
        "failed-precondition",
        "Cannot revoke a clinicalAdmin from here — edit the console directly.",
      );
    }
    const existingProfile = snap.data()?.profile ?? {};
    await userRef.set(
      { profile: { ...existingProfile, role: ROLES.patient } },
      { merge: true },
    );
    return { uid: targetUid, role: ROLES.patient };
  },
);
