import { createHash } from "node:crypto";

export type DomainCode =
  | "invalid-argument"
  | "not-found"
  | "failed-precondition"
  | "already-exists"
  | "resource-exhausted"
  | "permission-denied"
  | "unauthenticated";

export class DomainError extends Error {
  constructor(readonly code: DomainCode, message: string) {
    super(message);
    this.name = "DomainError";
  }
}

type RecordValue = Record<string, unknown>;

function record(value: unknown, label: string): RecordValue {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new DomainError("invalid-argument", `${label} must be an object.`);
  }
  return value as RecordValue;
}

function allowedKeys(value: RecordValue, allowed: readonly string[]): void {
  if (Object.keys(value).some((key) => !allowed.includes(key))) {
    throw new DomainError("invalid-argument", "Unknown fields are not accepted.");
  }
}

function text(value: unknown, label: string, maximum: number): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maximum ||
      value.trim().length === 0 || /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/u.test(value)) {
    throw new DomainError("invalid-argument", `${label} is not valid.`);
  }
  return value;
}

export function identifier(value: unknown, label: string, maximum = 96): string {
  if (typeof value !== "string" || value.length > maximum ||
      !/^[A-Za-z0-9][A-Za-z0-9_-]*$/u.test(value)) {
    throw new DomainError("invalid-argument", `${label} is not a valid identifier.`);
  }
  return value;
}

export function parseProfileInput(value: unknown): { displayName: string } {
  const input = record(value, "Input");
  allowedKeys(input, ["displayName"]);
  const displayName = text(input.displayName, "displayName", 60).trim();
  if (/[\r\n\t]/u.test(displayName)) {
    throw new DomainError("invalid-argument", "displayName must be a single line.");
  }
  return { displayName };
}

export interface PreparedInput {
  requestId: string;
  templateId: string;
  voiceId: string;
}

export function parsePreparedInput(value: unknown): PreparedInput {
  const input = record(value, "Input");
  allowedKeys(input, ["requestId", "templateId", "voiceId"]);
  return {
    requestId: identifier(input.requestId, "requestId", 128),
    templateId: identifier(input.templateId, "templateId"),
    voiceId: identifier(input.voiceId, "voiceId"),
  };
}

export interface LibraryPatch {
  chronicleId: string;
  bookmarked?: boolean;
  readingProgress?: number;
  audioPositionMs?: number;
}

export function parseLibraryPatch(value: unknown): LibraryPatch {
  const input = record(value, "Input");
  allowedKeys(input, ["chronicleId", "bookmarked", "readingProgress", "audioPositionMs"]);
  const result: LibraryPatch = { chronicleId: identifier(input.chronicleId, "chronicleId") };
  if (Object.hasOwn(input, "bookmarked")) {
    if (typeof input.bookmarked !== "boolean") {
      throw new DomainError("invalid-argument", "bookmarked must be a boolean.");
    }
    result.bookmarked = input.bookmarked;
  }
  if (Object.hasOwn(input, "readingProgress")) {
    const progress = input.readingProgress;
    if (typeof progress !== "number" || !Number.isFinite(progress) || progress < 0 || progress > 1) {
      throw new DomainError("invalid-argument", "readingProgress must be between 0 and 1.");
    }
    result.readingProgress = progress;
  }
  if (Object.hasOwn(input, "audioPositionMs")) {
    const position = input.audioPositionMs;
    if (typeof position !== "number" || !Number.isSafeInteger(position) || position < 0 || position > 86_400_000) {
      throw new DomainError("invalid-argument", "audioPositionMs must be an integer between 0 and 86400000.");
    }
    result.audioPositionMs = position;
  }
  if (Object.keys(result).length === 1) {
    throw new DomainError("invalid-argument", "At least one library field is required.");
  }
  return result;
}

export function parseChronicleInput(value: unknown): { chronicleId: string } {
  const input = record(value, "Input");
  allowedKeys(input, ["chronicleId"]);
  return { chronicleId: identifier(input.chronicleId, "chronicleId") };
}

export function requestKey(uid: string, requestId: string): string {
  return createHash("sha256").update(JSON.stringify([uid, requestId])).digest("hex");
}

export function payloadHash(input: Pick<PreparedInput, "templateId" | "voiceId">): string {
  return createHash("sha256").update(JSON.stringify([input.templateId, input.voiceId])).digest("hex");
}

/** Prepared copies have a separate write-abuse cap, not an AI generation quota. */
export const PREPARED_COPY_DAILY_LIMIT = 100;

export function preparedUsageKey(uid: string, utcDate: string): string {
  return createHash("sha256").update(JSON.stringify([uid, utcDate])).digest("hex");
}

export function nextPreparedCopyCount(current: unknown): number {
  if (current === undefined) return 1;
  if (typeof current !== "number" || !Number.isSafeInteger(current) || current < 0) {
    throw new DomainError("failed-precondition", "Prepared-copy usage requires recovery.");
  }
  if (current >= PREPARED_COPY_DAILY_LIMIT) {
    throw new DomainError("resource-exhausted", "Your 100 prepared copies for this UTC day have been used. Try again after 00:00 UTC.");
  }
  return current + 1;
}

function storagePath(value: unknown): string {
  const path = text(value, "storagePath", 512);
  if (!/^[A-Za-z0-9][A-Za-z0-9_./-]*$/u.test(path) ||
      path.split("/").some((part) => part === "" || part === "." || part === "..")) {
    throw new DomainError("invalid-argument", "Media must use a relative Storage object path.");
  }
  return path;
}

export interface Segment {
  text: string;
  kind: "legend" | "context";
  citationId?: string;
}

export interface Citation {
  id: string;
  title: string;
  author: string;
  page: string;
  note: string;
  url?: string;
}

export interface PublishedTemplate {
  id: string;
  siteId: string;
  title: string;
  subtitle: string;
  genre: string;
  style: string;
  mood: string;
  seed: string;
  chapter: number;
  segments: Segment[];
  citations: Citation[];
  voiceIds: string[];
  language: "en";
  contentVersion: number;
  contentKind: "prepared-demo";
  audioByVoice: Record<string, { storagePath: string; status: "ready" }>;
  imagePath?: string;
  nextIds?: string[];
}

function parseTemplate(value: unknown, templateId: string): PublishedTemplate {
  const data = record(value, "Template");
  if (data.id !== templateId || data.language !== "en" || data.contentKind !== "prepared-demo" ||
      !Number.isSafeInteger(data.contentVersion) || (data.contentVersion as number) < 1 ||
      (data.contentVersion as number) > 100_000 ||
      !Number.isSafeInteger(data.chapter) || (data.chapter as number) < 1 || (data.chapter as number) > 1000) {
    throw new DomainError("invalid-argument", "Template metadata is not valid.");
  }
  if (!Array.isArray(data.citations) || data.citations.length > 100 ||
      !Array.isArray(data.segments) || data.segments.length === 0 || data.segments.length > 100 ||
      !Array.isArray(data.voiceIds) || data.voiceIds.length === 0 || data.voiceIds.length > 20) {
    throw new DomainError("invalid-argument", "Template content is not valid.");
  }
  const citations = data.citations.map((item): Citation => {
    const citation = record(item, "Citation");
    const result: Citation = {
      id: identifier(citation.id, "citation id"),
      title: text(citation.title, "citation title", 500),
      author: text(citation.author, "citation author", 500),
      page: text(citation.page, "citation page", 500),
      note: text(citation.note, "citation note", 3000),
    };
    if (citation.url !== undefined && citation.url !== null) {
      const url = text(citation.url, "citation url", 2000);
      if (new URL(url).protocol !== "https:") {
        throw new DomainError("invalid-argument", "Citation URLs must use HTTPS.");
      }
      result.url = url;
    }
    return result;
  });
  const citationIds = new Set(citations.map((item) => item.id));
  if (citationIds.size !== citations.length) {
    throw new DomainError("invalid-argument", "Citation IDs must be unique.");
  }
  const segments = data.segments.map((item): Segment => {
    const segment = record(item, "Segment");
    if (segment.kind !== "legend" && segment.kind !== "context") {
      throw new DomainError("invalid-argument", "Segment kind is not valid.");
    }
    const result: Segment = { text: text(segment.text, "segment text", 20_000), kind: segment.kind };
    if (segment.citationId !== undefined && segment.citationId !== null) {
      const citationId = identifier(segment.citationId, "citationId");
      if (!citationIds.has(citationId)) {
        throw new DomainError("invalid-argument", "A referenced citation is missing.");
      }
      result.citationId = citationId;
    }
    return result;
  });
  if (segments.reduce((sum, segment) => sum + segment.text.length, 0) > 200_000) {
    throw new DomainError("invalid-argument", "Template content is too large.");
  }
  const voiceIds = data.voiceIds.map((voice) => identifier(voice, "voiceId"));
  if (new Set(voiceIds).size !== voiceIds.length) {
    throw new DomainError("invalid-argument", "Voice IDs must be unique.");
  }
  const audioByVoice: PublishedTemplate["audioByVoice"] = {};
  const rawAudio = record(data.audioByVoice, "audioByVoice");
  for (const [voiceId, value] of Object.entries(rawAudio)) {
    const audio = record(value, "Audio");
    if (!voiceIds.includes(voiceId) || audio.status !== "ready") {
      throw new DomainError("invalid-argument", "Template audio is not valid.");
    }
    audioByVoice[voiceId] = { storagePath: storagePath(audio.storagePath), status: "ready" };
  }
  const result: PublishedTemplate = {
    id: templateId,
    siteId: identifier(data.siteId, "siteId"),
    title: text(data.title, "title", 300),
    subtitle: text(data.subtitle, "subtitle", 500),
    genre: text(data.genre, "genre", 200),
    style: text(data.style, "style", 200),
    mood: text(data.mood, "mood", 200),
    seed: text(data.seed, "seed", 3000),
    chapter: data.chapter as number,
    segments,
    citations,
    voiceIds,
    language: "en",
    contentVersion: data.contentVersion as number,
    contentKind: "prepared-demo",
    audioByVoice,
  };
  if (data.imagePath !== undefined && data.imagePath !== null) {
    result.imagePath = storagePath(data.imagePath);
  }
  if (data.nextIds !== undefined) {
    if (!Array.isArray(data.nextIds) || data.nextIds.length > 20) {
      throw new DomainError("invalid-argument", "nextIds is not valid.");
    }
    result.nextIds = data.nextIds.map((id) => identifier(id, "nextId"));
  }
  return result;
}

/** Only server-published, validated content can become a private snapshot. */
export function publishedTemplate(value: unknown, templateId: string): PublishedTemplate {
  if (value === undefined || value === null || (value as RecordValue).status !== "published") {
    throw new DomainError("not-found", "The prepared story is not published.");
  }
  try {
    return parseTemplate(value, templateId);
  } catch {
    throw new DomainError("failed-precondition", "The published story requires an editorial update.");
  }
}
