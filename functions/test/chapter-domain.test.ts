import assert from "node:assert/strict";
import { test } from "node:test";
import { parseChapterProgressPatch } from "../src/chapters.js";
import { DomainError } from "../src/domain.js";

const valid = { chapterId: "onon-child", contentVersion: 1 };
function invalid(value: unknown): void {
  assert.throws(() => parseChapterProgressPatch(value),
    (error) => error instanceof DomainError && error.code === "invalid-argument");
}

test("chapter playback patches preserve valid zero and independent boolean values", () => {
  assert.deepEqual(parseChapterProgressPatch({ ...valid, audioPositionMs: 0, bookmarked: false, completed: false }), {
    ...valid, audioPositionMs: 0, bookmarked: false, completed: false,
  });
  assert.deepEqual(parseChapterProgressPatch({ ...valid, bookmarked: true }), { ...valid, bookmarked: true });
  assert.equal(parseChapterProgressPatch({ ...valid, audioPositionMs: 240_000 }).audioPositionMs, 240_000);
});

test("chapter progress rejects forged identity, content, invalid IDs and empty patches", () => {
  for (const value of [null, [], "chapter", undefined, 5, valid,
    { ...valid, bookmarked: true, uid: "another-user" },
    { ...valid, bookmarked: true, narration: "forged" },
    { ...valid, chapterId: "chapters/other", bookmarked: true },
    { ...valid, chapterId: "", bookmarked: true },
  ]) invalid(value);
});

test("chapter versions, playback positions and booleans are strongly bounded", () => {
  for (const contentVersion of [0, -1, 0.5, 100_001, NaN, Infinity, "1", null]) {
    invalid({ ...valid, contentVersion, bookmarked: true });
  }
  for (const audioPositionMs of [-1, 0.5, NaN, Infinity, 86_400_001, "100", null]) {
    invalid({ ...valid, audioPositionMs });
  }
  for (const field of ["bookmarked", "completed"]) {
    for (const value of [0, 1, "true", null]) invalid({ ...valid, [field]: value });
  }
});
