# Öv Firebase backend — эхний суурь

> **2026-10-18:** Одоогийн target нь `ov-ai-5ae61`, default mode нь `BACKEND_MODE=cloud`. [Cloud шилжүүлэлтийн бодит төлөв](CLOUD_MIGRATION_STATUS.mn.md)-ийг үзнэ үү. Доорх хуучин dev/emulator setup нь өмнөх үеийн тайлбар; Storage/Functions болон catalog publish нь billing хүлээж байна.


Огноо: 2026-10-17.

Англи түүхэн цувралын нэмэлт: Onon River нь Kharkhorin-той ижил place card → Place/Tone/Voice → Reader/Player → next path урсгалыг ашиглана. Нийт таван chronological chapter, Chapter 1-ийн хоёр өөр tone, дөрвөн narrator-ийн 24 ширхэг 4 минутын аудио бэлэн. `createPreparedChronicle`, `patchLibraryItem`, `deleteChronicle` нь local Firebase-д immutable content snapshot, parent path, bookmark/progress хадгална. Нэвтрэлтийн үндсэн account namespace бүр тусдаа local anonymous Firebase session-тэй; live Google cloud sync биш. [Ажиллуулах ба шалгах](SECRET_HISTORY_ENGLISH.mn.md). Хуучин Kharkhorin demo хадгалалт хэвээр.

## Одоо хэрэгжсэн зүйлс

- Node 22-д зориулсан TypeScript Cloud Functions; region `asia-northeast1`.
- Firebase Authentication шаарддаг profile, prepared story snapshot, library progress/bookmark, soft-delete API.
- Нэг request-ийг давтахад ижил бүтээл буцаах transaction; өөр payload-тай давтан ашиглахыг хориглоно. Template дараа өөрчлөгдсөн ч хадгалсан текст/эх сурвалж/version өөрчлөгдөхгүй.
- Хэрэглэгч бүрийн өдөр тутмын prepared-copy хязгаар 100, UTC 00:00-д шинэ өдөр. Давхар retry болон татгалзсан хүсэлт квот хэрэглэхгүй. Энэ нь ирээдүйн AI/TTS квотоос тусдаа.
- Firestore/Storage rules: public catalog, owner-only private content, custom claim-тэй admin-only research, бүх client write хаалттай.
- Live Functions дээр App Check шаарддаг; local Functions emulator дээр л enforcement суллана.
- Emulator seed: 4 газар, 11 demo template, 44 бүтэн audio + 4 зураг. Бүх story `prepared-demo`; verified fact эсвэл шинээр AI үүсгэсэн гэж тэмдэглэхгүй.
- FlutterFire client adapter, typed snapshot models, realtime profile/library/story streams, callable wrappers, authenticated Storage reference.

19 дэлгэцийн үндсэн апп одоо Firebase Auth-тай холбогдсон: Google social sign-in, session restore/sign-out, UID бүрийн local library тусгаарлалт ажиллана. Apple-ийн код бэлэн боловч Developer/provider тохиргоо хүлээж live товч идэвхгүй. Default `AUTH_MODE=live`; `AUTH_MODE=emulator` нь fake social account ашиглана. Story/library болон player нь prepared local өгөгдлөө ашигласан хэвээр; Firestore sync, versioned content migration, private audio cache/player adapter дараагийн ажил. Бодит AI/TTS, бүртгэлтэй хоёр provider account-ыг холбох/merge хийх UI, account бүрэн устгах, фото upload, public share API ороогүй. [Social auth тохиргоо](SOCIAL_AUTH_SETUP.md).

## Cloud project ба local project

- Firebase dev project ID: `ov-chronicles-dev-20261016`, display name `Ov Chronicles Dev`. [Console нээх](https://console.firebase.google.com/project/ov-chronicles-dev-20261016/overview).
- CLI alias: `dev`. Default нь хамгаалж `demo-ov-chronicles` emulator project хэвээр.
- Firebase Terms-ийг эзэмшигч зөвшөөрсний дараа project холболт амжилттай болсон.
- Cloud Firestore `(default)` database: Standard / Native mode, `asia-northeast1` (Tokyo), free tier. Firestore rules болон 3 composite index deploy амжилттай.
- Anonymous Auth болон Google provider идэвхтэй; тохиргоо `firebase.json`-д хадгалагдсан. Admin API-аар `anonymous.enabled: true`, `google.com: enabled`, Auth subtype `IDENTITY_PLATFORM` гэдгийг баталсан. Google app нэр `Öv Chronicles`, эзэмшигчийн сонгосон public support email `enkhjin@geret.mn`. Apple provider идэвхгүй. Web local Auth-д `localhost`, `127.0.0.1` authorized domains нэмсэн.
- iOS (`mn.ov.ovChronicles`), Android (`mn.ov.ov_chronicles`), Web app бүртгэл бэлэн. Public SDK тохиргоо `app/lib/backend/firebase_options_dev.dart`-д байна; өөрөө автоматаар холбогдохгүй.
- 2026-10-16-нд эзэмшигч одоохондоо төлбөргүй local emulator ашиглахаар сонгосон. Cloud Billing API-аар `billingEnabled: false` гэдгийг баталсан; live Functions/Storage/Hosting deploy, cloud content seed хийгээгүй. Cloud Functions болон Storage нь Blaze шаарддаг. [Functions deployment](https://firebase.google.com/docs/functions/get-started), [Storage billing](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).

Cloud-д цааш ажиллуулахад: эзэмшигч billing/Blaze сонгох → Storage bucket → App Check providers/debug token → Storage rules ба Functions deploy → зөвшөөрсөн content/media seed. Одоогийн cloud database хоосон. Emulator demo seed script live project руу бичихийг зориуд хориглодог. `firebase_options_dev.dart` дахь Storage bucket-ийн нэр нь provision хийгдсэн гэсэн үг биш.

## Local ажиллуулах

Node 22, Java 21+, npm хэрэгтэй. Firebase CLI нь repository dependency тул global install шаардлагагүй.

```sh
npm ci
npm test
npm run emulators:test
```

`emulators:test` нь Auth/Firestore/Storage/Functions-ийг эхлүүлж, rules болон HTTP callable тестүүдийг дараалан ажиллуулна. Дараа нь бодит catalog/media seed хийж Firebase client SDK-аар sign-in → profile → private story snapshot → audio bytes → progress → delete урсгалыг шалгаад emulator-уудыг унтраана. Энэ команд cloud төсөлд холбогдохгүй.

Тогтмол ажиллуулахдаа эхний Terminal:

```sh
npm run emulators:start
```

Хоёр дахь Terminal:

```sh
npm run seed:emulator
```

`emulators:start` нь `emulator-data/` доторх өмнөх session-ийг импортолж, Ctrl+C-ээр хэвийн хаахад Auth/Firestore/Storage өгөгдлийг экспортолно. Эхний удаа import folder байхгүй тухай мэдэгдээд хоосон эхэлнэ; дээрх seed-ийг ажиллуулна. Seed нь catalog-ийг шинэчилдэг, хэрэглэгчийн library-г арилгадаггүй. Энэ folder нь Git-д орохгүй. `emulators:test` нь тусдаа түр өгөгдөлтэй, хадгалсан session-ийг импортлохгүй.

Flutter client-ээр бүтэн урсгалыг шалгах тусдаа developer entry:

```sh
cd app
flutter run -d chrome -t lib/main_firebase_check.dart
```

`Run backend check` товч нь бодит FlutterFire SDK-аар нэвтрэлт → catalog/profile → private snapshot → audio bytes → bookmark/progress → устгал/replay-ийг шалгаад sign out хийнэ. Энэ entry нь 19 дэлгэцийн demo UI-тай library нэгтгэхгүй; үндсэн prototype `lib/main.dart` хэвээр.

| Service | Loopback endpoint |
|---|---|
| Auth | `127.0.0.1:9099` |
| Firestore | `127.0.0.1:18080` |
| Functions | `127.0.0.1:5001` |
| Storage | `127.0.0.1:9199` |

Firestore 8080 дээр энэ компьютерийн nginx ажиллаж байгаа учраас 18080 сонгосон. Түүнийг зогсоогоогүй. Emulator-ууд default loopback тул өөр төхөөрөмжөөс шууд хандахгүй. Physical device test хийх үед зөвхөн development сүлжээний тохиргоог тусад нь хийнэ.

Энэ host дээр emulator cache-г `/private/tmp/ov-firebase-emulators`, Java-г Temurin 21 болгож шалгасан. Өөрийн орчинд тохируулах жишээ:

```sh
env JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home FIREBASE_EMULATORS_PATH=/private/tmp/ov-firebase-emulators npm run emulators:test
```

Seed-ийг Flutter fixture-ээс дахин гаргах:

```sh
dart app/tool/export_firebase_seed.dart > seed/catalog.json
```

## API

| Callable | Оролт | Үр дүн |
|---|---|---|
| `ensureProfile` | `displayName` | `uid`, `displayName` |
| `createPreparedChronicle` | `requestId`, `templateId`, `voiceId` | `chronicleId`, `status`, `replayed`, `contentVersion` |
| `patchLibraryItem` | `chronicleId`, bookmark/progress/audio position patch | `chronicleId`, `status` |
| `deleteChronicle` | `chronicleId` | `chronicleId`, `status: deleted` |

Request бүрийн UID-г Auth token-оос авна. Клиент uid, role, generated segments зэрэг privileged утга илгээж болохгүй. IDs, урт, unknown fields, progress/position утгууд сервер дээр шалгагдана.

## Өгөгдөл ба файлууд

| Байршил | Зориулалт / client эрх |
|---|---|
| `sites/{id}` | Public газар |
| `storyTemplates/{id}` | Published catalog public, draft зөвхөн admin уншина |
| `chronicles/{id}` | UID-тай immutable snapshot, active үед зөвхөн эзэмшигч уншина |
| `users/{uid}` | Profile, зөвхөн эзэмшигч уншина |
| `users/{uid}/library/{id}` | Хувийн bookmark/progress, зөвхөн эзэмшигч уншина |
| `generationRequests/{hash}` | Серверийн idempotency бүртгэл |
| `usage/{hash}` | Серверийн өдөр тутмын prepared-copy тоолуур |
| `sources`, `facts`, `conflicts`, `adminAudit` | Admin-only read; server write |
| Storage `catalog/` | Public demo media, server write |
| Storage `chronicles/{uid}/{id}/{file}` | Owner + active Chronicle ownership шалгаж уншина |
| Storage `users/{uid}/covers/{file}` | Owner-only read, upload server API дараа |

Бусад path, nested subcollection-д default deny үйлчилнэ. Private media-д байнгын нийтэд нээлттэй download-token URL үүсгэхгүй. Flutter authenticated reference-ээр bytes/file cache татаж байж player-д өгнө.

`deleteChronicle` нь одоогоор soft delete: library entry арилгаж, хуучин request сэргээхээс хамгаалах tombstone үлдээнэ. Бүх account/media-г бүрэн устгах lifecycle нь тусдаа ажил; энэ API-г full account deletion гэж нэрлэхгүй.

## Шалгалтын нотолгоо

- TypeScript strict build ба 10 domain unit test давсан.
- Firestore/Storage rules-ийн 9 emulator test давсан.
- Auth emulator token-оор actual callable HTTP integration: 10 дэд шалгалт + suite wrapper, бүгд давсан.
- Seed/client SDK smoke: 4 газар, immutable private story, request replay, Karen M4A-ийн 235045 bytes, progress, soft deletion, deleted replay баталсан.
- Бодит FlutterFire Web client-ийн `main_firebase_check.dart` шалгалт browser дээр PASS: typed catalog/profile/snapshot parsing, authenticated 235045 M4A bytes, bookmark/progress/audio position round trip, delete/replay/library removal, sign-out. Backend болон шалгах web дэлгэц тус тус loopback дээр ажиллана.
- Flutter-ийн нийт 32 тест (24 өмнөх + 8 backend contract) давсан; analyzer issue байхгүй; web release build амжилттай.
- Runtime npm dependency audit: `npm audit --omit=dev` — 0 vulnerability.
- Firebase plugin-уудын шаардлагаар iOS minimum 15.0 болсон. Firebase Apple SDK 12.19.0 / 42 pod-тай `flutter build ios --simulator --debug` амжилттай; `app/build/ios/iphonesimulator/Runner.app` гарсан. Android SDK энэ host дээр байхгүй тул Android release build шалгаагүй.

Flutter ашиглах жишээ ба App Check тохиргоо: [client guide](FIREBASE_CLIENT.md). Серверийн input/response дэлгэрэнгүй: [functions guide](../functions/README.md).
