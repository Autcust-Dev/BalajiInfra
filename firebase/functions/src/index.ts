import { beforeUserSignedIn } from "firebase-functions/v2/identity";
import { computeClaimsWithAuthenticatedRole } from "./claims";

// Sets the `role: "authenticated"` custom claim Supabase's third-party Firebase auth
// integration requires (CLAUDE.md §4 rule 14) — nothing else: no other claims, no secrets,
// no network calls. 2nd gen, region asia-south1 to match the Supabase project (Mumbai).
//
// Requires the Firebase project to be upgraded to Identity Platform and on the Blaze plan
// before this can be deployed — see firebase/README.md. Not deployed yet.
export const beforeSignIn = beforeUserSignedIn(
  { region: "asia-south1" },
  (event) => ({
    customClaims: computeClaimsWithAuthenticatedRole(event.data?.customClaims),
  }),
);
