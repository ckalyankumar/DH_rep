/** Mirrors lib/clinical_review/clinical_review_schema.dart field names,
 * plus the reviewer-access-request collection added for the admin portal.
 */
export const REVIEWER_REQUESTS_COLLECTION = "reviewerAccessRequests";

export const REQUEST_STATUS_PENDING = "pending";
export const REQUEST_STATUS_APPROVED = "approved";
export const REQUEST_STATUS_REJECTED = "rejected";

export interface ReviewerAccessRequestDoc {
  email: string;
  uid: string;
  displayName?: string | null;
  note?: string | null;
  status: string;
  requestedAt: FirebaseFirestore.Timestamp;
  decidedBy?: string | null;
  decidedAt?: FirebaseFirestore.Timestamp | null;
  decisionNote?: string | null;
}
