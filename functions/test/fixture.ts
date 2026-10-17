/** Small editorial fixture; it is never generated or accepted from a client. */
export function preparedFixture(id = "test-story"): Record<string, unknown> {
  return {
    id,
    status: "published",
    siteId: "kharkhorin",
    title: "A prepared story",
    subtitle: "Chapter I",
    genre: "Legend",
    style: "Lyrical",
    mood: "Quiet",
    seed: "An imagined arrival.",
    chapter: 1,
    language: "en",
    contentVersion: 1,
    contentKind: "prepared-demo",
    segments: [
      { text: "An imagined traveller arrived.", kind: "legend" },
      { text: "This is an editorial demo.", kind: "context", citationId: "editorial" },
    ],
    citations: [{
      id: "editorial",
      title: "Editorial note",
      author: "OV",
      page: "Demo",
      note: "Original fiction for interaction testing.",
      url: null,
    }],
    voiceIds: ["samantha", "daniel"],
    audioByVoice: { samantha: { storagePath: `catalog/audio/samantha/${id}.m4a`, status: "ready" } },
    imagePath: "catalog/images/silver-tree.jpg",
    nextIds: ["chapter-two"],
  };
}
