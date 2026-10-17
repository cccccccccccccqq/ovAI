# Authenticated prepared-content backend

Node 22 Cloud Functions, deployed in `asia-northeast1`. Every callable requires
Firebase Authentication. App Check enforcement is enabled in cloud deployments;
only `FUNCTIONS_EMULATOR=true` disables it for the local Functions emulator.

| Callable | Accepted input | Result |
| --- | --- | --- |
| `ensureProfile` | `displayName` (trimmed, 1–60 characters) | `uid`, `displayName` |
| `createPreparedChronicle` | `requestId`, `templateId`, `voiceId` | `chronicleId`, `status`, `replayed`, `contentVersion` |
| `patchLibraryItem` | `chronicleId` plus one or more of `bookmarked`, `readingProgress`, `audioPositionMs` | `chronicleId`, `status` |
| `deleteChronicle` | `chronicleId` | `chronicleId`, `status: "deleted"` |

Unknown fields are rejected. IDs accept ASCII letters, numbers, `_` and `-`,
with a letter or number first. IDs are at most 96 characters; `requestId` allows
128. Progress accepts finite numbers in `[0, 1]`. Audio position accepts integers
in `[0, 86400000]` milliseconds.

The creation callable copies a validated `status: "published"` document from
`storyTemplates` into a private, immutable `chronicles` snapshot and creates its
entry under `users/{uid}/library`. It does not call an AI service or synthesize
audio. Narration is marked unavailable unless the published template provides
an uploaded Storage object for the selected voice.

A SHA-256 request key scopes idempotency to `(uid, requestId)`. The request record,
snapshot and library entry commit in one Firestore transaction. Concurrent
retries return the same snapshot. Reusing a request ID with another template or
voice fails. Replaying after an editorial update returns the original content
version. Soft deletion removes the library entry, keeps a private tombstone,
and prevents an old request from restoring it. Physical media deletion and full
account deletion are separate lifecycle work.

Each account can create 100 new prepared copies per UTC day (reset at 00:00 UTC).
The server-only `usage` counter commits in the same transaction as the snapshot
and request record, so concurrent calls cannot exceed the cap. Replays and
rejected requests do not count. This controls cloud writes and is separate from
any future AI or TTS quota. Reaching the cap returns `resource-exhausted`.

Run unit tests from the repository root:

```sh
npm run test --workspace functions
```

Run the real callable and rule tests with the repository's emulator suite:

```sh
npm run emulators:test
```

The integration suite creates anonymous Auth emulator accounts and calls the
actual HTTP callable endpoints. It covers unauthenticated requests, concurrent
retries, forged content, cross-account access, progress validation, immutable
versions, unavailable audio and replay after deletion. It never contacts a live
Firebase project. Without emulator environment variables, the integration test
is explicitly skipped.
