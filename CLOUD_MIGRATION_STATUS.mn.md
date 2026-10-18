# Cloud шилжүүлэлтийн төлөв — 2026-10-18

Target: `ov-ai-5ae61` (project number `765364993612`).

## Cloud дээр хийсэн

- Standard Firestore `(default)` database: `asia-northeast1`.
- Firestore хамгаалалтын rules болон шаардлагатай indexes deploy хийсэн.
- iOS (`mn.ov.ovChronicles`), Android (`mn.ov.ov_chronicles`), Web app бүртгэсэн.
- Google provider идэвхтэй; anonymous provider идэвхгүй. Apple provider нь Apple Developer тохиргоо хүлээсэн хэвээр.
- Cloud SDK тохиргоо, Google OAuth client ID болон iOS callback scheme шинэчилсэн.
- iOS App Attest, web reCAPTCHA Enterprise App Check provider бүртгэсэн. Cloud Functions-ийн App Check enforcement хэвээр.
- Web-ийн public build тохиргоо: `app/config/cloud.web.json`.

## Cloud deploy үргэлжилж байна

Эзэмшигч Blaze billing account холбосон; API-аар `billingEnabled: true` баталгаажсан.

`ov-ai-5ae61.firebasestorage.app` bucket ASIA-NORTHEAST1-д үүссэн, Storage rules deploy хийгдсэн. Таван Cloud Functions ACTIVE, Auth/App Check байхгүй хүсэлтүүд HTTP 401-ээр хаагдаж байгаа нь шалгагдсан. Бүх медиа upload/read-back баталгаажуулсны дараа catalog publish, client smoke шалгалт хийгдэнэ.

## Код болон өгөгдөл бэлэн

- `BACKEND_MODE=cloud` default; app-ийн Auth, catalog, шинэ prepared story болон library нь нэг Firebase app/UID ашиглана.
- Onon, Kharkhorin зэрэг бүх газрын шинэ prepared story cloud Functions-оор хадгалагдана.
- 39 public/editorial document, 72 media object (60,262,788 bytes).
- Manifest SHA-256: `6ea0ed6494b1363be3df1a63fe30efcc65b03fff52edfc46ced12574b9451b2f`.
- Importer нь өөр project, өөр bucket, өөр агуулгатай existing document/object-ийг хүлээн авахгүй; дарж бичихгүй.
- Emulator-ийн хиймэл хэрэглэгч, хуучин private library/progress-ийг cloud account-д хамааруулж хуулахгүй. Хуучин local хадгалалт тусдаа хэвээр.

Шилжүүлэх алхам: [CLOUD_CATALOG_MIGRATION.mn.md](CLOUD_CATALOG_MIGRATION.mn.md).
Client тохиргоо: [CLOUD_CONNECTION.md](app/docs/CLOUD_CONNECTION.md).

## Explicit local mode

```sh
cd app
flutter run --dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator --dart-define-from-file=.maps-ios.local.json
```

iPhone Simulator дээр Google/Apple emulator provider-ийн login цонх дэмжигдээгүй; local guest болон web emulator login хэрэглэнэ.
Cloud хувилбарт local server-ээс fallback хийхгүй. Billing болон catalog publish дуусаагүй үед шинэ cloud catalog харагдахгүй байж болно.
