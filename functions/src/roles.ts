/**
 * Mirrors lib/clinical_review/clinical_roles.dart. Keep in lockstep — this
 * is server-side, so it is the actual enforcement point for granting
 * clinicalReviewer/clinicalAdmin; firestore.rules only blocks the *client*
 * path (see roleUpdateAllowed() in firestore.rules, which permits only
 * patient<->doctor changes from the app).
 */
export const ROLES = {
  patient: "patient",
  doctor: "doctor",
  clinicalReviewer: "clinicalReviewer",
  clinicalAdmin: "clinicalAdmin",
} as const;

export type Role = (typeof ROLES)[keyof typeof ROLES];

export const PROTECTED_ROLES: Set<string> = new Set([
  ROLES.clinicalReviewer,
  ROLES.clinicalAdmin,
]);

export function canonicalizeRole(raw: unknown): Role | null {
  if (typeof raw !== "string") return null;
  switch (raw.trim().toLowerCase()) {
    case "patient":
      return ROLES.patient;
    case "doctor":
      return ROLES.doctor;
    case "clinicalreviewer":
      return ROLES.clinicalReviewer;
    case "clinicaladmin":
      return ROLES.clinicalAdmin;
    default:
      return null;
  }
}

export function isAdminRole(raw: unknown): boolean {
  return canonicalizeRole(raw) === ROLES.clinicalAdmin;
}

export function isStaffRole(raw: unknown): boolean {
  const role = canonicalizeRole(raw);
  return role === ROLES.clinicalReviewer || role === ROLES.clinicalAdmin;
}
