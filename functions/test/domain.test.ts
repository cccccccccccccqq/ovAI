import assert from "node:assert/strict";
import { test } from "node:test";
import {
  DomainError,
  parseChronicleInput,
  parseLibraryPatch,
  parsePreparedInput,
  parseProfileInput,
  nextPreparedCopyCount,
  payloadHash,
  publishedTemplate,
  requestKey,
  preparedUsageKey,
} from "../src/domain.js";
import { preparedFixture } from "./fixture.js";

function invalid(operation: () => unknown): void {
  assert.throws(operation, (error) => error instanceof DomainError && error.code === "invalid-argument");
}

test("profile names are trimmed, bounded, and accept Mongolian", () => {
  assert.deepEqual(parseProfileInput({ displayName: "  Амар  " }), { displayName: "Амар" });
  for (const displayName of ["", "  ", "x".repeat(61), "A\nB", "A\u0000B", 10, null]) {
    invalid(() => parseProfileInput({ displayName }));
  }
  invalid(() => parseProfileInput({ displayName: "A", role: "admin" }));
});

test("all callable payloads reject non-object or unknown inputs", () => {
  const parsers = [parseProfileInput, parsePreparedInput, parseLibraryPatch, parseChronicleInput];
  for (const parser of parsers) {
    for (const input of [null, [], "name", 3, undefined]) invalid(() => parser(input));
  }
  invalid(() => parsePreparedInput({ requestId: "r", templateId: "t", voiceId: "v", segments: [] }));
  invalid(() => parseChronicleInput({ chronicleId: "c", uid: "victim" }));
});

test("IDs prevent paths, URLs, empty values and excessive lengths", () => {
  for (const id of ["", "../users/x", "a/b", "https://example.org", "data:audio;base64,a", "a.b", "a b", "x".repeat(97)]) {
    invalid(() => parseChronicleInput({ chronicleId: id }));
  }
  assert.deepEqual(parsePreparedInput({ requestId: "r_123-xyz", templateId: "silver-tree", voiceId: "samantha" }), {
    requestId: "r_123-xyz", templateId: "silver-tree", voiceId: "samantha",
  });
  invalid(() => parsePreparedInput({ requestId: "x".repeat(129), templateId: "t", voiceId: "v" }));
});

test("patch accepts zero, complete progress, and independent partial fields", () => {
  assert.deepEqual(parseLibraryPatch({ chronicleId: "c", bookmarked: false, readingProgress: 0, audioPositionMs: 0 }), {
    chronicleId: "c", bookmarked: false, readingProgress: 0, audioPositionMs: 0,
  });
  assert.equal(parseLibraryPatch({ chronicleId: "c", readingProgress: 1 }).readingProgress, 1);
  assert.equal(parseLibraryPatch({ chronicleId: "c", audioPositionMs: 86_400_000 }).audioPositionMs, 86_400_000);
});

test("patch rejects non-finite progress and invalid playback positions", () => {
  for (const readingProgress of [-1, 1.001, NaN, Infinity, -Infinity, "0.3", null]) {
    invalid(() => parseLibraryPatch({ chronicleId: "c", readingProgress }));
  }
  for (const audioPositionMs of [-1, 1.2, 86_400_001, NaN, Infinity, "100", null]) {
    invalid(() => parseLibraryPatch({ chronicleId: "c", audioPositionMs }));
  }
  invalid(() => parseLibraryPatch({ chronicleId: "c" }));
  invalid(() => parseLibraryPatch({ chronicleId: "c", bookmarked: 1 }));
  invalid(() => parseLibraryPatch({ chronicleId: "c", bookmarked: null }));
  invalid(() => parseLibraryPatch({ chronicleId: "c", bookmarked: true, title: "forged" }));
});

test("request identity is scoped to an account and preserves boundaries", () => {
  assert.equal(requestKey("u", "r"), requestKey("u", "r"));
  assert.notEqual(requestKey("u", "r"), requestKey("other", "r"));
  assert.notEqual(requestKey("ab", "c"), requestKey("a", "bc"));
  assert.match(requestKey("u", "r"), /^[a-f0-9]{64}$/u);
  assert.notEqual(payloadHash({ templateId: "t", voiceId: "v" }), payloadHash({ templateId: "t", voiceId: "other" }));
});

test("prepared copy quota counts to 100 and uses account plus UTC day", () => {
  assert.equal(nextPreparedCopyCount(undefined), 1);
  assert.equal(nextPreparedCopyCount(0), 1);
  assert.equal(nextPreparedCopyCount(99), 100);
  assert.throws(() => nextPreparedCopyCount(100), (error) => error instanceof DomainError && error.code === "resource-exhausted");
  for (const current of [-1, 1.2, NaN, Infinity, "99", null]) {
    assert.throws(() => nextPreparedCopyCount(current), (error) => error instanceof DomainError && error.code === "failed-precondition");
  }
  assert.notEqual(preparedUsageKey("a", "2026-10-16"), preparedUsageKey("b", "2026-10-16"));
  assert.notEqual(preparedUsageKey("a", "2026-10-16"), preparedUsageKey("a", "2026-10-17"));
});

test("prepared snapshot copies only editorial content, including optional media", () => {
  const input: Record<string, unknown> = { ...preparedFixture(), injectedRole: "admin", uid: "attacker" };
  const result = publishedTemplate(input, "test-story");
  assert.equal(result.contentKind, "prepared-demo");
  assert.equal(result.contentVersion, 1);
  assert.equal(result.audioByVoice.samantha?.storagePath, "catalog/audio/samantha/test-story.m4a");
  assert.equal(result.audioByVoice.daniel, undefined);
  assert.equal(Object.hasOwn(result, "uid"), false);
  assert.equal(Object.hasOwn(result, "injectedRole"), false);
  assert.equal(Object.hasOwn(result.citations[0]!, "url"), false);
  (input.segments as { text: string }[])[0]!.text = "Changed later";
  assert.equal(result.segments[0]?.text, "An imagined traveller arrived.");
});

test("unpublished or missing content is unavailable", () => {
  for (const input of [undefined, null, { ...preparedFixture(), status: "draft" }]) {
    assert.throws(() => publishedTemplate(input, "test-story"), (error) =>
      error instanceof DomainError && error.code === "not-found");
  }
});

test("server content validation rejects forged kinds, unsafe media and broken citations", () => {
  const invalidTemplates = [
    { ...preparedFixture(), id: "other" },
    { ...preparedFixture(), contentKind: "generated" },
    { ...preparedFixture(), contentVersion: 0 },
    { ...preparedFixture(), imagePath: "data:image/png;base64,abc" },
    { ...preparedFixture(), imagePath: "catalog/../private/user.jpg" },
    { ...preparedFixture(), audioByVoice: { samantha: { storagePath: "https://example.org/a.mp3", status: "ready" } } },
    { ...preparedFixture(), audioByVoice: { unknown: { storagePath: "catalog/a.mp3", status: "ready" } } },
    { ...preparedFixture(), citations: [] },
    { ...preparedFixture(), voiceIds: ["samantha", "samantha"] },
    { ...preparedFixture(), segments: [] },
  ];
  for (const input of invalidTemplates) {
    assert.throws(() => publishedTemplate(input, "test-story"), (error) =>
      error instanceof DomainError && error.code === "failed-precondition");
  }
});
