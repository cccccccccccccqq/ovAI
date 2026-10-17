# Flutter prototype v0.1 — 19 дэлгэцийн хэрэгжүүлэлтийн төлөвлөгөө

Огноо: 2026-10-15.

## Тогтсон хүрээ

Хэрэглэгчийн сонголт: **бэлдсэн контент + demo profile; эхлээд UX шалгах**.

Зорилго: одоогийн 19 дэлгэцийн дизайныг Flutter дээр хэрэгжүүлж, navigation, сонголт, local persistence, бодит audio playback, зураг сонголт, file export болон demo аяллын урсгалыг ажиллуулах. AI/backend хүлээлгүй UI ба хэрэглэгчийн үйлдлийг шалгах боломжтой болгоно.

Энэ төлөвлөгөөний v0.1 хэрэгжүүлэлт `app/` дотор бий. 19 дэлгэцийн route, локал өгөгдөл, аудио, pack, экспорт ажиллана. Шалгалтын дэлгэрэнгүй: [verification](app/docs/VERIFICATION.md).

## Prototype-д бодитой ажиллах зүйлс

- 19 дэлгэц хооронд navigation, back, tab, буцаж ирэхэд хадгалагдсан төлөв.
- Demo profile үүсгэх/сонгох, гарах, guest хязгаарлалт; төхөөрөмж дээр хадгалах. Жинхэнэ account эсвэл cross-device sync гэж харуулахгүй; password авах шаардлагагүй.
- 4 газрын curated өгөгдөл, map/site selection, хайлт, demo өгөгдөлд нийцсэн filter.
- Place/tone/style/mood/seed/voice сонголт нэг draft-д хадгалагдах.
- Бэлдсэн контентын manifest-ээс сонголтод тохирох өгүүлэмж нээж, local library-д шинэ instance хадгалах. Demo content гэдгийг тодорхой харуулах.
- Текст, citation, fact/legend тэмдэглэгээ, bookmark, reading position.
- Бодит аудио файл, play/pause/seek/speed, voice sample, playback position хадгалалт.
- Зураг сонгох, камер байгаа төхөөрөмж дээр зөвшөөрөлтэй capture; үгүй бол photo picker/preset fallback. Сонгосон зураг cover болдог; зургийг AI шинжилсэн гэж харуулахгүй.
- Settings, offline draft/queue, demo pack install/delete, бодит local file state.
- Share card PNG, PDF үүсгэх, системийн share sheet. Share sheet нээх нь өөрөө email/message автоматаар илгээхгүй.

## 19 дэлгэцийн хүлээн авах шалгуур

| # | Дэлгэц | Prototype дээр ажиллах үйлдэл |
|---|---|---|
| 1 | Main | Begin/login/guest урсгал зөв route нээж, өмнөх local session-ийг сэргээнэ |
| 2 | SignUp | Demo profile нэр оруулах/сонгох, validation, guest үргэлжлүүлэх; Apple/Google бодит нэвтрэлт мэт ажиллуулахгүй |
| 3 | Steppe | 4 газар, хайлт, газрын сонголт, sheet, bookmark, tab; era filter өгөгдөлтэй таарна |
| 4 | InscribePlace | Site/preset/gallery/camera сонголтыг draft-д хадгална; permission denied үед fallback |
| 5 | InscribeTone | Genre/style/mood/seed сонголт дараагийн алхамд дамжина; reroll өөр seed сонгоно |
| 6 | InscribeVoice | Preview бодит аудио тоглоно; summary нь draft-ийн утгатай таарна; full recording байгаа хувилбарыг сонгоно |
| 7 | Writing | Local demo job явц, cancel/retry; дууссан instance зөв Reader-д нээгдэнэ; бодит AI verification гэж нэрлэхгүй |
| 8 | Reader | Сонгосон өгүүлэмж/cover, audio controls, bookmark, citation sheet, text/audio position |
| 9 | ReaderEnd | Ашигласан эх сурвалж, үргэлжлэлийн бэлдсэн сонголт; сонгосон салаа дараагийн chapter болно |
| 10 | Scrolls | Mine/Journeys/Explore өөр dataset, search/filter, saved story нээх/устгах |
| 11 | Orda | Profile, бодит local library-ийн тоо, journey progress, settings, demo logout |
| 12 | FieldMap | Газрууд, зай/сонголт; зөвшөөрсөн үед foreground GPS; GPS-гүй үед тэмдэглэсэн demo байршил |
| 13 | Geofence | Demo route дээр ойртсон site-ийн prompt, open/dismiss, давтан гарах cooldown; demo GPS тодорхой тэмдэглэгээтэй |
| 14 | Offline | Draft queue хадгалах, edit/cancel, downloaded content нээх; demo connection mode солиход үргэлжлүүлэх |
| 15 | Journey | Бодит chapter list, сонгосон branches, уншсан/сонссон явц, share/export |
| 16 | ShareCard | PNG/PDF файл гаргах, share sheet; copy link зөвхөн бодитоор resolve хийдэг demo/app/web route-тай үед |
| 17 | Playback | Урьдчилан бэлдсэн route-ийн chapter playlist, previous/next/play/seek, map marker chapter-тай таарна |
| 18 | Settings | Theme, text size, audio speed зэрэг тохиргоо хадгалагдана; permission сонголт OS-ийн бодит төлөвийг тусгана |
| 19 | Downloads | Demo pack-ийн файлуудыг local storage-д суулгах, явц, хэмжээ, cancel/delete; restart дараа төлөв зөв |

Downloads-ийн эхний fixture нь bundled pack-ийг local storage-д суулгах хэлбэртэй байж болно. Үүнийг интернэтээс татсан мэт тайлбарлахгүй. Remote pack нэмж шалгах үед static HTTPS file endpoint ашиглаж болно; application backend шаардлагагүй. Map tile region download энэ scope-д орохгүй.

Offline дэлгэцийн одоогийн «AI автоматаар бичээд notification ирнэ» гэсэн copy-г demo job queue/resume-тэй нийцүүлнэ. Local prepared content нь offline үед уншигдана. Background push амлахгүй.

## Бэлдэх өгөгдөл ба медиа

1. 4 site: ID, нэр, coordinates, summary, era tags, cover.
2. Хархорумын 3 chapter-тай нэг бүтэн journey, 2–3 сонгож үзэх branch; бусад 3 site-д дор хаяж нэг curated story.
3. Story бүрт fact/legend segments, citation metadata; баталгаажаагүй sample-г verified fact гэж нэрлэхгүй.
4. Voice sample болон full narration файлын coverage manifest.
5. Empty library, populated library, offline, failure, cancelled, resumed гэсэн demo scenario fixtures.
6. Poppins/Inter font файлууд, icon/logo SVG, зурагт утгатай asset нэр.

Одоогийн Tone дэлгэц 5 genre × 4 style × 4 mood × 5 seed = нэг site-д 400 комбинацтай. Дээр нь 4 voice нэмэгдэх тул бүх комбинацад тусдаа story/audio бэлтгэх нь prototype-д хэт их. Сонголт бүр ажиллахдаа юу өөрчилдгийг contract-оор тогтооно:

- Curated story-ийн дэмжсэн genre/style/seed хувилбарууд manifest-д байна.
- Mood нь бэлтгэсэн intro/legend block сонгох эсвэл visual treatment-д нөлөөлөхдөө UI тайлбартай байна; arbitrary AI rewrite гэж харагдуулахгүй.
- Unsupported комбинацад тохирох preset санал болгоно эсвэл option-ийг тайлбартай идэвхгүй болгоно. Сонголтыг чимээгүй үл тоохгүй.
- Voice preview ба full narration тусдаа asset. Kore гэж сонгоод өөр recording тоглуулахгүй. Эхний default story дээр 4 voice-ийн recording бэлдэж болно; бусад story-д боломжтой narrator-уудыг л идэвхжүүлнэ.
- Custom seed-ийг хадгалж болно; бэлдсэн story нь тэр хүсэлтийн шинэ AI хариу биш гэдгийг харуулна.

## Кодын суурь

```text
Flutter screens/widgets
       ↓
Riverpod controllers + shared session/draft/player state
       ↓
Repository interfaces
       ↓
Local demo repositories + persistent storage + bundled content
```

UI болон data layer-ийг салгах нь дараа нь local demo repository-г Firebase/backend implementation-аар солиход дэлгэцүүдээ дахин бичихгүй байх суурь болно. [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)

Models: `DemoProfile`, `Site`, `ChronicleDraft`, `DemoGenerationJob`, `Chronicle`, `StorySegment`, `Citation`, `Journey`, `PlaybackProgress`, `DownloadPack`, `AppSettings`.

Технологийн санал: Riverpod, go_router, just_audio, flutter_svg; local storage adapter, image picker, share/export adapter. SQLite зэрэг database нь mobile persistence-д тохирно; web хувилбар шаардлагатай бол storage implementation-ийг тусад нь нийцүүлнэ. [SQLite cookbook](https://docs.flutter.dev/cookbook/persistence/sqlite), [go_router](https://pub.dev/packages/go_router), [just_audio](https://pub.dev/packages/just_audio).

Background audio ба background geofence нь эхний UX prototype-ийн зайлшгүй нөхцөл биш. Foreground player ба location behavior-ийг бодитоор ажиллуулна. Route playback нь бэлдсэн аяллын replay; хэрэглэгчийн бодит хөдөлгөөнийг бичиж авсан track гэж үзүүлэхгүй.

## Хийх дараалал

1. **P01 — Setup ба design system:** Flutter төсөл, asset/font, theme, reusable controls, router, 19 route placeholder. Navigation graph болон screenshot reference тогтоох.
2. **P02 — Shared data/state:** models, seed manifest, demo profile, local persistence, resettable scenarios, draft сонголт хадгалах.
3. **P03 — Нэг бүтэн урсгал:** Main → SignUp/guest → Steppe → Place → Tone → Voice → Writing → Reader → ReaderEnd → Scrolls. Бодит sample audio, bookmark, citations.
4. **P04 — Аялал ба сан:** Orda, Journey, Playback, Settings; өмнөх session/progress сэргээх.
5. **P05 — Төхөөрөмжийн үйлдлүүд:** FieldMap, Geofence, Offline, Downloads, ShareCard, gallery/camera, PNG/PDF/share. Unsupported platform fallback.
6. **P06 — QA ба review build:** 19 дэлгэцийн acceptance matrix, small-screen/text scaling, airplane mode/restart, permission denied, file cancel/delete, media interruptions.

Ажиллах боломжтой завсрын үр дүн нь P03. Бүх 19 дэлгэцийн interactive acceptance нь P06 дээр дуусна. Өнгө/зай бүрийг тусдаа тестээр давтахгүй; persistence, draft propagation, playlist, cancel/resume, export болон гол navigation урсгалд утгатай шалгалт хийнэ.

## Бэлэн болсны нотолгоо

- Нэг native target дээр ажиллах review build, 19 дэлгэцийн walkthrough; бусад target-ийн шалгасан/шалгаагүй төлөв тодорхой.
- Demo profile үүсгээд 2 бүтээл хадгалж, app restart хийсний дараа хэвээр байна.
- Tone/voice сонголт summary, Reader, audio asset-тай таарна.
- Reader болон Playback нь бодит аудио тоглуулж, seek/next/back зөв ажиллана.
- PNG/PDF нь бодит файл болж нээгдэнэ; share sheet хэрэглэгчид сонголт өгнө.
- Offline/demo location/error scenario-г давтаж шалгаж болно.
- Blank/no-op товч үлдэхгүй; scope-оос гадуурх боломж бүр availability тайлбартай байна.
- Local demo-г real AI, real authentication, live verification гэж буруу нэрлэхгүй.

## Хугацааны төлөвлөлт

Урьдчилсан инженерийн үнэлгээ, амлалт биш: asset/content/audio бэлэн, туршлагатай 2 хөгжүүлэгчтэй бол 19 дэлгэцийн local prototype ойролцоогоор **5–8 ажлын өдөр**. Нэг хөгжүүлэгчтэй бол **8–12 ажлын өдөр**. Flutter суралцах, медиа бэлтгэх, camera/GPS/device setup, нэмэлт platform QA энэ хугацааг өсгөнө.

Эхлээд нэг native target-ийг reference болгон тогтоож, core flow-г review хийсний дараа хоёр дахь mobile platform болон шаардлагатай web preview-г шалгана. Дизайны эх iPhone тул default review target нь iOS simulator байж болно; бодит төхөөрөмжийн camera/GPS behavior-ийг тусад нь шалгана.
