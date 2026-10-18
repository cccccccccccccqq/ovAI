# Secret History — English shared flow

Энэ хувилбар нь Kharkhorin-той ижил component, дэлгэц, reader/player болон library ашиглана. Тусдаа монгол дэлгэц, тусдаа player ашиглахгүй.

## Контент

- Place: **Onon River**, Steppe дээрх бусад газартай ижил card.
- Chapter 1: **A Child by the Onon** (Plainspoken) эсвэл **Where the River Holds a Beginning** (Lyrical). Хоёр preset нь өөр текст, өөр бичлэгтэй.
- Chapter 2–5: Hoelun-ийн гэр бүл, ах дүүсийн зөрчил, Тайчуудаас оргосон нь, найман шарга ба Boorchu. Жинхэнэ гарчгууд `seed/secret-history-english.json`-д байна.
- Chapter бүр 4:00. Samantha, Daniel, Karen, Moira гэсэн хуучин дөрвөн narrator бүрт тусдаа бодит AAC бичлэгтэй; 6 template × 4 voice = 24 файл.
- Эхийн §59–93-д тулгуурласан, шинээр бичсэн англи synopsis. Paragraph бүр source citation-тай. PDF/TXT-ийг public Storage-д оруулаагүй.
- Эртний зам, айлын бууцны солбицлыг зохиогоогүй. Onon/Deliün Boldog нь тайлбартай approximate area. Reader доторх chapter map аудионы хэсгийг дагаж шилжинэ.

## Үндсэн урсгал

1. Steppe → **Onon River** → **Read a prepared story** шууд эхний reader нээнэ.
2. **Inscribe this place** эсвэл Inscribe tab → Place → Tone → Voice → Prepare my chronicle.
3. Reader → Play → Choose your path → дараагийн chapter. Parent болон narrator дараагийн chapter-т хадгалагдана.
4. Scrolls library, bookmark, share болон saved journey нь хуучин нийтлэг UI-г ашиглана.

## Database

- `sites/onon`, `series/temujin-childhood-en`, `storyTemplates/{id}`, `chapters/{canonicalId}`, `historicalPlaces/{id}`: shared editorial catalog.
- `chronicles/{id}`: server-created immutable English text/citations/version/audio reference/parent snapshot.
- `users/{uid}/library/{id}`: reading/audio progress, bookmark, parent linkage.
- Storage `catalog/audio/{voice}/{template}.m4a`: нийтэлсэн өгүүлэмж.
- RPC: `createPreparedChronicle`, `patchLibraryItem`, `deleteChronicle`. Сервер owner, published content, next path, ижил narrator, аудионы хугацааг шалгана.
- Guest болон үндсэн account namespace бүр өөр local Firebase session ашиглана; өөр account-ийн local түүхийг нийлүүлэхгүй. Live Google-той cloud синк хараахан биш.
- Хуучин `temujin-childhood` / `onon-child` монгол pilot архивлагдсан. Өмнөх progress болон audio-г устгаагүй. Хуучин `/history/onon-child` link стандарт англи reader рүү шилжинэ.

## Ажиллуулах

Repository root:

```sh
npm run emulators:start
# Өөр terminal:
npm run seed:history:en
npm run history:en:verify
```

Энэ Mac дээр Java шаардлагатай бол `JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home`, emulator cache-д `FIREBASE_EMULATORS_PATH=/private/tmp/ov-firebase-emulators` ашиглаж болно.

Web:

```sh
cd app
flutter build web --release --no-wasm-dry-run --dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator --dart-define-from-file=.maps-web.local.json
python3 -m http.server 8766 --bind 127.0.0.1 --directory build/web
```

`http://127.0.0.1:8766/#/steppe` → Onon River. Өгөгдөл local бөгөөд emulator-ыг хэвийн хаахад `emulator-data/`-д export хийнэ. GitHub-ийг database болгон ашиглахгүй.

## Шалгалт

Backend unit/integration болон real Firebase client SDK smoke нь таван chapter-ийн холбоос, дөрвөн voice-ийн Storage hash, шинэ client дээр bookmark/progress сэргээх, account isolation, хугацааны bounds-ийг шалгана. Flutter shared-flow tests нь actual English seed-ээр Place → Lyrical → Daniel → Reader → Chapter 2 болон snapshot/progress reload-ийг шалгана. Native widget tests нь decoder-ийг stub хийдэг; бодит playback-ийг browser дээр тусад нь шалгана.

Аудио дахин бэлдэх authoring script: `scripts/generate-secret-history-english-audio.py`. Бүх 24 аудионы hash/timing report: `seed/secret-history-english-audio.production.json`. Нийтэлсэн content/audio өөрчлөхдөө version болон Storage path-ийг хамт өсгөнө.

### 2026-10-18 баталгаажуулалт

Browser дээр Lyrical + Daniel сонгож стандарт Reader-аар Chapter 1-ийг тоглуулсан; 4:00 duration баталсан. Choose your path → Chapter 2 шилжилт, Daniel narrator болон parent холбоос Firestore-д хадгалагдсан. Bookmark болон бодит playback progress-ийг server-оос уншиж шалгасан. Refresh хийсний дараа Chapter 2-ыг 1:02-оос үргэлжлүүлэн тоглуулсан. Аудио ачаалах алдаа гарсан ч өмнөх 1:32 progress устахгүй regression тест нэмсэн.

Эцсийн Flutter analyzer: алдаагүй. Бүх Flutter regression тест: **90 passed**. Backend unit: **15 passed**, integration: **18 passed**, real Firebase SDK English catalog/voice/path/progress smoke: passed.
