import { describe, expect, it } from "vitest";
import { computeClaimsWithAuthenticatedRole } from "./claims";

describe("computeClaimsWithAuthenticatedRole", () => {
  it("sets role: authenticated when there are no existing claims", () => {
    expect(computeClaimsWithAuthenticatedRole(undefined)).toEqual({
      role: "authenticated",
    });
  });

  it("preserves other existing claims untouched", () => {
    expect(
      computeClaimsWithAuthenticatedRole({ someOtherClaim: "x" }),
    ).toEqual({ someOtherClaim: "x", role: "authenticated" });
  });

  it("overwrites a stale/incorrect role claim rather than merging it", () => {
    expect(computeClaimsWithAuthenticatedRole({ role: "anon" })).toEqual({
      role: "authenticated",
    });
  });
});
