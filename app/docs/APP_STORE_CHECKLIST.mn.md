# App Store-д гаргах checklist — öv AI (iOS)

2026-10-18-нд шинэчилсэн. Bundle ID: `mn.ov.ovChronicles`, Team ID: `4CS2X8UTJX`, version `1.0.0+1`, Firebase project `ov-ai-5ae61`.

Тэмдэглэгээ: 🔴 заавал · 🟡 эрсдэлтэй · ✅ кодонд хийгдсэн · 👤 console/портал дээр хүн хийх

---

## 1. Apple account ба App Store Connect

- [ ] 👤🔴 **Apple Developer Program** membership ($99/жил)
- [ ] 👤🔴 App Store Connect дээр app үүсгэх (Bundle ID `mn.ov.ovChronicles`)
- [ ] 👤🔴 Xcode Team-ийг идэвхтэй membership-тэй account болгох (`4CS2X8UTJX`)
- [ ] 👤 Agreements, Tax, Banking (үнэгүй апп бол Free Apps agreement хангалттай)

## 2. Sign in with Apple (Guideline 4.8)

- [x] ✅ `Runner.entitlements` Runner target-ийн Debug, Release, Profile build-уудад `CODE_SIGN_ENTITLEMENTS`-ээр холбогдсон
- [x] ✅ iOS build дээр "Continue with Apple" анхнаасаа идэвхтэй. Web, Android дээр `--dart-define=APPLE_SIGN_IN_ENABLED=true` хэвээр
- [ ] 👤🔴 Developer портал → Identifiers → `mn.ov.ovChronicles` → **Sign in with Apple** болон **App Attest** capability идэвхжүүлэх
- [ ] 👤🔴 Keys → Sign in with Apple key (`.p8`), Key ID, Team ID. Repo-д бүү оруул
- [ ] 👤🔴 Firebase Console (`ov-ai-5ae61`) → Authentication → **Apple** provider идэвхжүүлж, key мэдээллээ оруулах. Token revoke ажиллахад энэ шаардлагатай
- [ ] 👤 Web/Android-д хэрэгтэй бол Services ID + Return URL `https://ov-ai-5ae61.firebaseapp.com/__/auth/handler`
- [ ] 👤 Бодит iPhone дээр шалгах: анх нэвтрэх, Hide My Email, гарах, дахин нэвтрэх

## 3. Account устгах (Guideline 5.1.1(v))

- [x] ✅ Апп дотор: **Profile → Account → Delete account** → баталгаажуулах dialog → дахин нэвтрэх → устгах
- [x] ✅ Cloud Function `deleteAccount`: `users/{uid}` (library, chapterProgress-тэй нь), `chronicles`, `generationRequests`, `usage`, Storage `chronicles/{uid}/`, `users/{uid}/`, дараа нь Firebase user-ийг устгана. Сүүлийн 5 минутад нэвтрээгүй бол татгалзана
- [x] ✅ Apple user-ийн токеныг `revokeTokenWithAuthorizationCode`-оор revoke хийнэ
- [x] ✅ Устгасны дараа төхөөрөмж дээрх мэдээллийг цэвэрлээд Welcome руу буцна
- [x] ✅ Тест: Flutter (controller + widget), functions unit, emulator integration (өөр хэрэглэгчийн мэдээлэлд хүрэхгүйг шалгасан)
- [ ] 👤🔴 Functions-ийг deploy хийх: `npx firebase-tools deploy --only functions --project ov-ai-5ae61`

## 4. Backend / тохиргоо

- [x] ✅ Production project = `ov-ai-5ae61` (PR #2-оос хойш app ба backend нэг project-д)
- [x] ✅ `Info.plist`-ийн Google URL scheme-ийг `ov-ai-5ae61`-ийн iOS client ID (`765364993612-…`) болгож зассан. Өмнө нь хуучин project-ийнх байсан тул native Google sign-in унах байсан
- [x] ✅ App Check: iOS дээр App Attest (DeviceCheck fallback) кодонд байгаа, `appattest-environment = production` entitlement нэмэгдсэн
- [ ] 👤🔴 Storage bucket provision (Blaze plan)
- [ ] 👤🔴 **Google Maps API key**: release машин дээр `ios/Flutter/Maps.local.xcconfig` дотор `GOOGLE_MAPS_API_KEY=...`, мөн build-д `--dart-define=GOOGLE_MAPS_API_KEY=...`
- [ ] 👤🔴 Map ID: build-д `--dart-define=GOOGLE_MAP_ID=<бодит Map ID>` (өгөхгүй бол `DEMO_MAP_ID`)
- [ ] 👤🟡 Maps key-г iOS bundle ID-аар хязгаарлах
- [ ] 👤🟡 Firebase Console → App Check → iOS app-д App Attest provider бүртгэж, enforcement асаах
- [ ] 👤🟡 Rules deploy: `npx firebase-tools deploy --only firestore:rules,storage --project ov-ai-5ae61`

## 5. App icon

- [x] ✅ Бүх iOS icon RGB, alpha суваггүй. Брэндбүүкийн ger тэмдэг, ногоон дэвсгэр дээр цагаан (`scripts/make-app-icons.py`)
- [ ] 👤 Launch screen-ийг бодит төхөөрөмж дээр шалгах

## 6. Info.plist ба нууцлал

- [x] ✅ Camera, Photo Library тайлбар: "...cover of a story you create. The photo stays on this device."
- [x] ✅ `ITSAppUsesNonExemptEncryption = false`
- [x] ✅ `PrivacyInfo.xcprivacy` Runner-т нэмэгдэж, resources-д холбогдсон (UserDefaults CA92.1, FileTimestamp C617.1. Collected: Name, Email, UserID, OtherUserContent; tracking байхгүй)
- [x] ✅ Privacy Policy: `https://ov-ai-5ae61.web.app/privacy.html` (англи + монгол). Settings болон Sign-in дэлгэцээс холбоостой
- [ ] 👤🔴 Web-ийг deploy хийсний дараа дээрх URL-ийг App Store Connect-д оруулах
- [ ] 👤🔴 App Store Connect → **App Privacy**: Name, Email Address, User ID, Other User Content → App Functionality, Linked to user, Not used for tracking. Location, Photos нь төхөөрөмжөөс гарахгүй тул "collected" биш
- [ ] 👤🟡 Support URL (жишээ нь `https://ov-ai-5ae61.web.app`), Terms of Use (заавал биш)

## 7. Агуулга ба чанар (Guideline 2.1)

- [x] ✅ Хэрэглэгчид харагдах "demo", "prototype" текстийг бүгдийг сольсон. Fiction болон эх сурвалжийн тайлбарын утга хэвээр
- [x] ✅ Тестүүд: Flutter 110/110, functions 16/16 unit + 19/19 emulator integration
- [x] ✅ `flutter analyze`: алдаагүй
- [ ] 👤 Бодит iPhone, iPad дээр бүх урсгалыг шалгах (iPad-ийн screenshot бас шаардлагатай)
- [ ] 🟡 Crashlytics хараахан нэмэгдээгүй (native тохиргоо шаардлагатай, дараагийн алхам)

## 8–10. Build, metadata, илгээх

TestFlight-ийн бүрэн зааврыг [TESTFLIGHT_SETUP.mn.md](TESTFLIGHT_SETUP.mn.md)-ээс харна уу. GitHub Actions build хийгээд upload хийнэ.

```bash
flutter build ipa --release \
  --dart-define=AUTH_MODE=live \
  --dart-define=GOOGLE_MAPS_API_KEY=... \
  --dart-define=GOOGLE_MAP_ID=...
```

- [ ] Transporter эсвэл Xcode Organizer-оор upload → TestFlight
- [ ] Screenshots: iPhone 6.9" (1320×2868), iPad 13" (2064×2752)
- [ ] Metadata: `ov-app-store-metadata.md` (Travel / Education)
- [ ] App Review notes: Guest горимоор нэвтрэхгүйгээр ашиглах боломжтой. Account устгах: Profile → Account → Delete account
- [ ] Submit for Review
