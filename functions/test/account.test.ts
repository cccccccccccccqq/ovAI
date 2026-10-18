import assert from "node:assert/strict";
import { test } from "node:test";
import { RECENT_SIGN_IN_SECONDS, requireRecentSignIn } from "../src/account.js";
import { DomainError } from "../src/domain.js";

test("account deletion requires a sign-in within the last five minutes", () => {
  const now = 1_800_000_000;
  requireRecentSignIn(now, now);
  requireRecentSignIn(now - RECENT_SIGN_IN_SECONDS, now);
  for (const authTime of [now - RECENT_SIGN_IN_SECONDS - 1, undefined, null, "1800000000", Number.NaN]) {
    assert.throws(
      () => requireRecentSignIn(authTime, now),
      (error) => error instanceof DomainError && error.code === "failed-precondition",
    );
  }
});
