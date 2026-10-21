# Öv — prototype-оос production v1 хүртэл

Огноо: 2026-10-15. Энэ нь одоогийн Flutter код, өмнөх migration analysis, хавсаргасан хоёр design document болон албан ёсны үйлчилгээний баримт дээр тулгуурласан хэрэгжүүлэх санал юм. Cloud төсөл, төлбөртэй үйлчилгээ, account эсвэл deployment энэ шинжилгээгээр үүсгээгүй. Design document доторх public repo/deploy/billing checklist-ийг хэрэглэгчийн гүйцэтгэх заавар гэж үзээгүй.

**2026-10-16 хэрэгжилтийн нэмэлт:** Firebase backend-ийн эхний суурь болон FlutterFire adapter хэрэгжиж, Auth/Firestore/Storage/Functions emulator, хамгаалалтын дүрэм, prepared snapshot/progress API-ийн бүтэн урсгал шалгагдсан. `ov-chronicles-dev-20261016` cloud project, Firestore rules/indexes, anonymous Auth, 3 platform app бүртгэл бэлэн. Эзэмшигч төлбөргүй emulator ашиглахаар сонгосон; billing, live Functions/Storage идэвхгүй. 19 дэлгэцийн UI/library migration болон AI/TTS үлдсэн. Дэлгэрэнгүй: [Firebase backend](BACKEND_FIREBASE.mn.md).

Одоогийн 19 дэлгэц, theme, persistent navigation, Reader, foreground player, camera/gallery болон export-ийн суурийг үргэлжлүүлэн ашиглана. Үлдсэн ажлын гол хэсэг нь account, өгөгдлийн загвар, серверийн AI/TTS, контентын хяналт, бодит offline хэрэглээ, төхөөрөмжийн найдвартай ажиллагаа юм. Дэлгэцийн тоогоор production-ийн бэлэн байдлыг хэмжихгүй.

## Одоогийн кодоор батлагдсан зөрүү

| Хэсэг | Одоо | Production-д хийх |
|---|---|---|
| Account | Төхөөрөмж дээр хадгалсан нэр / guest flag | Бодит хэрэглэгчийн ID, нэвтрэлт, account сэргээх/устгах, guest → account шилжилт |
| Хадгалалт | Library, queue, settings нэг SharedPreferences JSON | Stories/jobs/progress-д schema migration-тай local database; cloud sync; media-г тусдаа файл/object storage |
| Өгүүллэг | Chronicle нь templateId ба metadata хадгалж, текстээ bundled template-ээс авна | Бүтээлийн текст/segments, эх сурвалж, хэл, content version, media reference-ийг бие даан хадгалах |
| Үүсгэлт | Writing-ийн local delay → бэлэн template | Серверийн persistent job, бодит AI хариу, verification, алдаа/дахин оролдох/цуцлах |
| Аудио | Урьдчилан бэлдсэн M4A asset | Шинэ текстийн TTS; remote/cache/local эх үүсвэр сонгодог player; audio status |
| Downloads | Bundled demo file-ийг storage руу хуулна | Серверийн version-той pack татах; Reader/player тухайн татсан файлыг үнэхээр ашиглах |
| Байршил | FieldMap нээлттэй үед foreground GPS; demo arrival | Бодит GPS-ийн accuracy/cooldown/permission; background arrival-ийг scope-д орвол тусдаа native хэрэгжүүлэлт |
| Share | PNG/PDF, prepared-template link | Public болгох тодорхой үйлдэл, серверт хадгалсан story link, deep link, буцааж private болгох |
| Release | 24 автомат тест; web ба iOS simulator build | Android toolchain/release signing, physical-device integration, beta, monitoring, store submission |

Нотолгооны гол файлууд: `app/lib/core/models.dart`, `app/lib/core/app_state.dart`, `app/lib/core/audio_controller.dart`, `app/lib/core/download_controller.dart`, `app/lib/screens/inscribe_screens.dart`, `app/lib/screens/travel_screens.dart`, `app/docs/VERIFICATION.md`.

**Эхний чухал засвар:** `AppState.load()` одоогийн demo template/site/voice жагсаалтад байхгүй ID-тай бүтээлийг сэргээхгүй. API-аас шинэ өгүүллэг авдаг болгохын өмнө Chronicle model, restore болон migration-ийг өөрчлөх ёстой. Одоогийн demo library-г шинэ schema-д хөрвүүлж, текст/эх сурвалжийн snapshot-тай хадгална. Бусад account руу автоматаар хуваалцахгүй; import/ownership бодлогыг тогтооно.

## Санал болгож буй суурь

Flutter UI → repository/service интерфэйсүүд → Firebase Auth, Firestore, Storage, серверийн TypeScript Functions/Genkit + task queue → сонгосон AI/TTS үйлчилгээ.

- Одоогийн ChangeNotifier-ийг шууд бүхэлд нь солих шаардлагагүй. UI-аас demo template болон SharedPreferences-ийн шууд хамаарлыг салгах нь түрүүлж хийх ажил.
- `AuthRepository`, `StoryRepository`, `GenerationService`, `MediaRepository`, `DownloadService` гэсэн хариуцлагыг салгана.
- Firestore-д хэрэглэгч, газар, бүтээл, job, эх сурвалж, баталсан баримт; Storage-д зураг, аудио, эх файлууд байрлана.
- `users/{uid}/library/{storyId}`-д хувийн bookmark/reading/audio progress; shared story content-д хэрэглэгчийн хувийн явцыг холихгүй.
- Story нь generated content/version, evidence snapshot, language, visibility, server timestamp, text/audio/image-ийн тусдаа status-тай байна.
- Dev/staging/production орчныг ялгаж, CI-д analyze/test/build болон backend/rules шалгалт оруулна.

Энэ чиглэл нь сүүлд өгсөн Flutter system concept-той нийцнэ. Хамгийн эхний баримтын Next.js/web-only, тэмцээний хугацаа, anonymous generation зэрэг шийдвэрийг mobile production-д шууд хуулж хэрэглэхгүй.

## Хийх дараалал ба дууссан гэж үзэх шалгуур

| Үе | Ажил | Хүлээн авах үр дүн |
|---|---|---|
| P0 — өгөгдөл ба contract | Chronicle/evidence/media/job model, schema version, local migration, API request/response | Demo-оос шилжүүлсэн болон шинэ story app restart/update дараа хадгалагдана; bundled template өөрчлөгдсөн ч хадгалсан текст өөрчлөгдөхгүй |
| P1 — account ба backend | Firebase тохиргоо, сонгосон sign-in, guest linking, ownership/rules, library sync | Нэг account-аар хоёр төхөөрөмж дээр бүтээл нээгдэнэ; өөр account хувийн сан/аудиод хандахгүй |
| P2 — нэг газрын бүтэн урсгал | Хархорумын approved facts → generation → verification → текст → нэг хоолойн TTS | Хэрэглэгчийн сонголтоос шинэ өгүүллэг, тохирох аудио үүсэж cloud library-д хадгалагдана; app хаагаад нээхэд job сэргээнэ |
| P3 — контент ба admin | Үлдсэн 3 газар, canonical fallback, source/fact review, publish/unpublish, content version | 4 газрын нийтлэх контент хянагдсан эх сурвалжтай; засварын эзэн ба түүх бүртгэлтэй |
| P4 — mobile v1 | Бодит text/audio download, background audio/lock-screen controls, GPS, share/deep links | Airplane mode + cold restart дээр татсан бүтээл уншигдаж/сонсогдоно; утас түгжих, дуудлага/чихэвчний interruption зөв ажиллана |
| P5 — beta ба release | Physical iPhone/Android QA, signing, crash/error monitoring, backup/recovery, privacy/deletion, store материал | TestFlight/Android test build хэрэглэгчдээр шалгагдаж, гол acceptance алдаа хаагдсан, release/rollback заавартай |

Эхний beta нь P2-ийн нэг газрын урсгал. Production v1-ийн суурь нь P0–P5. Хугацааг багийн хүчин чадал, контентын бэлэн байдал, хэл/хоолой, platform access-ийг тогтоосны дараа үнэлнэ; энэ баримт календарийн амлалт биш.

## AI болон аудионы бодит урсгал

1. Flutter нь `requestId`, site, genre/style/mood, directive, narratorId, language гэсэн баталгаажуулсан хүсэлт явуулна. Хэрэглэгчийн UID/эрх/квотыг сервер батална.
2. Сервер job ID буцаана. Давхар даралт, network retry нэг logical job үүсгэж, нэг удаа квот тоолно.
3. Approved facts-ийн тогтсон version/snapshot авч, хүсэлтийн хүрээг шалгаад өгүүллэг үүсгэнэ.
4. Evidence ID/schema/conflict зэрэг кодын шалгалт болон агуулгын verification хийнэ. Баримт ба уран сэтгэмжийг ялгана. AI verification-ийг түүхэн үнэн байдлын бүрэн баталгаа мэт харуулахгүй.
5. Баталгаажсан текстийг Reader-д нээнэ. TTS-ийг тусдаа job-оор үүсгэнэ; TTS алдаа текст уншихыг хаахгүй. Зураг үүсгэлт мөн тусдаа optional алхам байна.
6. Аудиог story content hash + voice + language + TTS version-оор кэшлэнэ. Дахин сонсох бүрд дахин TTS дуудахгүй.
7. Job бүр bounded retry, timeout, checkpoint, stale-job recovery, cancel болон quota/credit-ийн тодорхой дүрэмтэй байна. Provider дуудлага эхэлсэн үед cancel нь тухайн зардлыг буцаах баталгаа биш; үр дүн нийтлэхийг зогсоох бодлого хэрэгтэй.

Урт ажлыг queue-д ажиллуулахад retry болон concurrency/rate limit тохируулж болно. [Firebase task queue functions](https://firebase.google.com/docs/functions/task-functions)

Текстийн хэл, UI-ийн хэл, аудионы хэлийг тусад нь сонгоно. Одоогийн англи demo-оос Монгол хэлтэй хувилбар руу орох бол газар/хүний нэрийн дуудлага, 2–3 минутын бүтэн уншлага, latency болон зардлыг сонгосон TTS дээр бодитоор харьцуулж байж voice-уудыг батална. Одоогийн macOS voice нэрийг шинэ үйлчилгээний өөр хоолойтой чимээгүй тааруулахгүй.

## Контент, эрх, үйл ажиллагаа

- Эх сурвалж бүрт title/author/license/url/page/section, raw quote болон reviewer хадгална. Normalized text нь raw quote-ийг орлохгүй.
- OCR-оос гарсан facts эхлээд draft; хүн хянаж approved болгосны дараа generation-д хэрэглэнэ. Эхний хувилбарт seed/script + энгийн review UI хангалттай; OCR automation дараа өргөжинө.
- Raw PDF/admin draft хувийн байсан ч Reader-д үзүүлэх зөвшөөрөгдсөн citation snapshot тусдаа байна.
- API secret серверт; private/public media-ийн эрх нь story visibility-тай ижил байна. Байнгын нийтэд нээлттэй audio URL-ийг private story-ийн хамгаалалт гэж тооцохгүй.
- Auth нь хэрэглэгчийг танина; App Check нь app/device attestation нэмнэ. Ownership rules, серверийн validation, квотыг тусад нь хэрэгжүүлнэ. [Firebase App Check](https://firebase.google.com/docs/app-check)
- Guest-ийн санг бодит account-тай холбоход тухайн Firebase UID-г хадгалах боломжтой. Давхардсан account-ийн merge, logout дараах cache тусгаарлалт мөн хэрэгтэй. [Firebase account linking](https://firebase.google.com/docs/auth/flutter/account-linking)
- Нэг хэрэглэгч/өдрийн квот, нийт queue concurrency, input/output length, abuse control, нэг бүтээлийн бодит token/TTS/storage/transfer хэмжилт хийнэ. Budget alert-аас гадна серверийн бодит хязгаар хэрэгтэй.
- Фото зураг AI руу илгээх боломж нэмэх үед илгээх зорилго, хадгалах/устгах хугацааг UI-д ойлгомжтой болгоно. Location history-г feature-д хэрэгтэй хэмжээнд л хадгална.
- Account устгах урсгал нь profile, private stories/media, library болон шаардлагатай холбоотой өгөгдлийн цэвэрлэгээг хамарна. Account creation-тэй App Store апп дотор account deletion эхлүүлэх боломж шаардана. [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)
- Контент, cover, narrator-ийн нийтлэх/арилжааны ашиглалтын эрхийг production asset сонголттой хамт баталгаажуулна.

## Offline ба төхөөрөмжийн шалгалт

- Local asset resolver нь татсан файл → remote media гэсэн бодит замыг сонгоно; manifest-д дурдсан файл байхгүй/эвдэрсэн бол pack-ийг incomplete гэж үзнэ.
- Pack-д content/voice/chapter coverage, version, checksum, byte count; interrupted download resume, storage-full error, delete/update-ийн найдвартай ажиллагаа орно.
- Offline үед шинэ AI generation-ийн хүсэлтийг draft/queue хэлбэрээр хадгалж, сүлжээтэй үед серверийн ажлыг эхлүүлнэ.
- Offline map нь text/audio download-оос тусдаа ажил. Одоогийн `tile.openstreetmap.org`-оос region pack урьдчилан татахыг зөвшөөрдөггүй; offline эрхтэй provider эсвэл өөрийн tile hosting сонгох шаардлагатай. [OSMF tile policy](https://operations.osmfoundation.org/policies/tiles/)
- Одоогийн foreground GPS-ийг бодит газарт accuracy, jitter, дахин notification гарах cooldown, permission denied, location service off гэсэн нөхцөлд шалгана.
- Background geofence/push, олон хэл/олон хоолой, automated illustration/OCR, public feed, subscriptions нь тус бүр өөр acceptance болон release шаардлагатай нэмэлт ажлууд. Тэдгээрийг үндсэн урсгал тогтвортой болсны дараа дарааллаар нэмнэ.

Release-ийн өмнө заавал турших гол нөхцөл: хоёр account-ийн эрх тусгаарлалт; хоёр төхөөрөмжийн sync; network loss/reconnect; app kill/restart; generation/TTS timeout; давхар request; old schema migration; download дутуу/эвдэрсэн/багтаамжгүй; camera/location denial; screen lock/audio interruption; private share/revoke; account deletion; production signing. Одоогийн widget тестүүд native decoder-ийг mock хийдэг тул эдгээрийн төхөөрөмжийн нотолгоог орлохгүй.

## Хэрэгжүүлэлт эхлэхэд тогтоох 4 зүйл

1. Эхний release-ийн UI, өгүүллэг, аудионы хэл болон зорилтот хэрэглэгч.
2. Guest-ийн generation хязгаар, Apple/Google/email-аас эхний sign-in аргууд.
3. Firebase/GCP төсөл, account эзэмшил, dev/prod access болон сарын төсвийн хүрээ.
4. v1-д background geofence, offline map, төлбөр орох эсэх. Үндсэн санал нь эхлээд account + 4 газар + бодит generation/TTS + library sync + text/audio offline + mobile release.

**Дараагийн хэрэгжүүлэх ажлын багц:** Chronicle/job/evidence model ба demo migration → Auth/Firestore/Storage/emulator/rules суурь → Хархорум дээр sign-in → generate → verified text → TTS → cloud library гэсэн нэг бүтэн урсгал.
