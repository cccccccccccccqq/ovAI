# Google болон Apple account-аар нэвтрэх тохиргоо

Апп Firebase Authentication ашиглан Google болон Apple account-аар нэвтэрнэ. Анх нэвтрэхэд Firebase user үүсэж, дараагийн удаа тухайн Firebase UID-тай хэрэглэгчийн session сэргээгдэнэ. Нууц үг, OAuth token-ийг аппын local profile-д хадгалахгүй; session-ийг Firebase SDK удирдана.

## Одоогийн орчин

- Default нь `BACKEND_MODE=cloud` (`AUTH_MODE=live` optional): бүртгэлтэй dev project `ov-ai-5ae61`-ийн бодит Firebase Authentication руу холбогдоно.
- `AUTH_MODE=emulator`-ийг тодорхой сонгосноор үнэгүй local Authentication emulator, project `demo-ov-chronicles`, порт `9099`-ийг ашиглана.
- Auth-ийн сонголт нь Cloud Functions, Firestore, Storage-ийн шилжилттэй тусдаа. Live auth ашиглах нь үлдсэн 19 дэлгэцийн контентыг cloud өгөгдөл болгохгүй.
- Firebase billing өөрчлөх шаардлагагүй. Google/Apple auth нь Spark-ийн хэрэглээний хязгаарт ажиллах боломжтой; Cloud Functions/Storage deploy-ийн Blaze шаардлага тусдаа хэвээр.
- 2026-10-16-нд хэрэглэгчийн зөвшөөрсөн support email-ээр Google provider идэвхжиж, web/iOS OAuth client-уудыг бодит Firebase config-оос татаж тохируулсан. Web client ID нь `DevFirebaseOptions.googleWebClientId`, iOS client ID нь `DevFirebaseOptions.ios.iosClientId`-д байна. iOS `Info.plist`-д Google-ийн reversed client ID URL scheme нэмэгдсэн.
- Хэрэглэгч одоогоор Apple Developer Program account-гүй. Apple-ийн live нэвтрэлт default-аар идэвхгүй; emulator дээр mock Apple account-аар UX-ийг шалгаж болно. Apple account болон provider-ийн тохиргоо бүрэн дууссаны дараа `APPLE_SIGN_IN_ENABLED=true` define-ээр идэвхжүүлнэ.

## Local emulator дээр шалгах

Repository root дээр emulator-уудаа ажиллуулна:

```sh
npm run emulators:start
```

`app` хавтсаас web аппыг ажиллуулна:

```sh
flutter run -d chrome --dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator
```

Emulator-ийн Google/Apple popup нь туршилтын account оруулах local хуудас харуулна. Энэ нь бодит Google эсвэл Apple account-ын зөвшөөрөл авах дэлгэц биш. Энд account үүсгэж, дахин нэвтрэх, session сэргээх, гарах болон хэрэглэгч хооронд өгөгдөл холилдохгүй байхыг шалгана. Туршилтын popup-д бодит account-ын нууц үг оруулахгүй.

Native emulator горимын social login бодит Google/Apple SDK-г санамсаргүй дуудахаас сэргийлж web туршилт руу чиглүүлнэ. Бодит provider-ийн нэвтрэлтийг доорх live тохиргоо дууссаны дараа төхөөрөмж дээр тусад нь шалгана.

## Google тохируулах

1. [Firebase Authentication → Sign-in method](https://console.firebase.google.com/project/ov-ai-5ae61/authentication/providers) дотор Google provider-ийг нээнэ.
2. Хэрэглэгчид харагдах app нэр болон project-ийн эзэмшигчийн сонгосон support email-ийг оруулж идэвхжүүлнэ. Support email нь OAuth зөвшөөрлийн дэлгэц дээр харагдах тул CLI-д нэвтэрсэн email-ийг автоматаар нийтлэхгүй.
3. Google provider идэвхжсэний дараа iOS, Android SDK config-ийг дахин татна. Өмнө татсан Firebase API key нь Google OAuth client ID-г орлохгүй.
4. Web local туршилт хийх бол Authentication → Settings → Authorized domains дотор ашиглах `localhost` эсвэл `127.0.0.1` hostname-ийг нэмнэ. Domain-д порт эсвэл URL зам оруулахгүй.

Одоогийн код native iOS/Android дээр албан ёсны `google_sign_in: ^7.2.0` plugin ашиглана: Google SDK-ээс ID token авч, Firebase `signInWithCredential`-д өгнө. Web дээр Firebase SDK-ийн `signInWithPopup` ашиглана. Нэвтрэхэд шаардагдах basic profile/email-ээс гадна Contacts зэрэг нэмэлт API scope авахгүй.

### iOS

- Bundle ID: `mn.ov.ovChronicles`.
- Google OAuth iOS client ID-г `GOOGLE_IOS_CLIENT_ID` define эсвэл `DevFirebaseOptions.ios.iosClientId`-д тохируулна.
- `Info.plist` → `CFBundleURLTypes` дотор татсан `GoogleService-Info.plist`-ийн `REVERSED_CLIENT_ID`-тай ижил URL scheme тохирсон. Өөр Firebase project/client руу шилжихэд энэ scheme-ийг мөн шинэчилнэ; Dart define URL scheme-ийг орлохгүй.
- Одоогийн dev client ID-уудыг кодын public Firebase config-оос уншина. Доорх `GOOGLE_IOS_CLIENT_ID` болон `GOOGLE_WEB_CLIENT_ID` define нь өөр client ID ашиглах үеийн optional override юм.

Native live ажиллуулах жишээ, бодит client ID-уудаар солино:

```sh
flutter run -d YOUR_IOS_DEVICE \
  --dart-define=AUTH_MODE=live \
  --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_OAUTH_CLIENT_ID \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```

Одоогийн dev project-ийг ашиглахад Google client ID define-үүдийг дахин өгөх шаардлагагүй:

```sh
flutter run -d YOUR_IOS_DEVICE --dart-define=AUTH_MODE=live
```

### Android

- Package name: `mn.ov.ov_chronicles`.
- Тухайн build-ийг sign хийдэг certificate-ийн SHA-1-ийг Firebase Android app бүртгэлд нэмнэ. Debug, release, Google Play app signing certificate нь өөр өөр SHA-тай байж болно.
- Энд `google-services.json`-оос config авахын оронд Dart config ашиглаж байгаа тул Google OAuth **web client ID**-г `DevFirebaseOptions.googleWebClientId`-аас уншина. Өөр client ашиглах бол `GOOGLE_WEB_CLIENT_ID` define-ээр override хийнэ. Android client ID-г энэ define-д өгөхгүй.
- 2026-10-16-ны шалгалтаар `~/.android/debug.keystore` байхгүй байсан. Android build/signing хийсний дараа бодит certificate-ийн SHA-г бүртгэнэ; таамгаар SHA оруулахгүй.

```sh
flutter run -d YOUR_ANDROID_DEVICE \
  --dart-define=AUTH_MODE=live \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```

## Apple тохируулах

Бодит Sign in with Apple тохируулахад Apple Developer Program account шаардлагатай. Апп IO Technology LLC-ийн team `W94G6F573L`-ээр sign хийгдэж, 2026-10-19-нд анхны TestFlight build (1.0.0 (1)) upload хийгдсэн.

1. [Apple Developer → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) дээр `mn.ov.ovChronicles` App ID-д Sign in with Apple-ийг идэвхжүүлнэ.
2. `Runner/Runner.entitlements` файлд Apple capability-ийн загвар бэлдсэн; **одоогийн build-д холбоогүй, capability идэвхгүй**. Ингэснээр Google login болон одоогийн signing тохиргоо Apple capability-тай provisioning profile шаардахгүй. Developer account бэлэн болсон үед Xcode → Runner → Signing & Capabilities → `+ Capability` → Sign in with Apple-ийг нэмнэ. Runner-ийн Debug/Release/Profile configuration-ийн `CODE_SIGN_ENTITLEMENTS` нь `Runner/Runner.entitlements` руу зааж байгааг шалгаж, төхөөрөмжийн provisioning profile-оо шинэчилнэ.
3. Web/Android дээр Apple ашиглах бол primary App ID-тай холбоотой Services ID үүсгэнэ. Domain нь `ov-ai-5ae61.firebaseapp.com`, Return URL нь:

   ```text
   https://ov-ai-5ae61.firebaseapp.com/__/auth/handler
   ```

4. Apple Sign in key үүсгэн Team ID, Key ID болон private `.p8` key-г Firebase Console-ийн Apple provider → OAuth code flow configuration-д оруулна. Services ID-г мөн Apple provider дээр тохируулна.
5. Private key-г Flutter/Dart код, repository, `.env` asset эсвэл чатад оруулахгүй. Firebase Console-ийн сервер талын provider тохиргоонд оруулна.

Дээрх provider, native capability, signing/provisioning тохиргоо дуусаж төхөөрөмж дээр шалгахад бэлэн болсны дараа Apple live login-ийг ажиллуулна. `APPLE_SIGN_IN_ENABLED=true` define дангаараа Apple capability эсвэл provider үүсгэхгүй:

```sh
flutter run -d YOUR_IOS_DEVICE \
  --dart-define=AUTH_MODE=live \
  --dart-define=APPLE_SIGN_IN_ENABLED=true
```

iOS-ийн native Apple authorization нь App ID/capability болон Apple-ийн өгсөн ID token ашиглана; Services ID нь web/Android-ийн OAuth урсгалд хамаарна. Firebase-ийн бүрэн тохиргоо болон token revocation-д OAuth code flow key шаардлагатай. Account deletion-ийг release хийхээс өмнө Apple token revoke болон хэрэглэгчийн өгөгдөл устгах урсгалтай бүрэн хэрэгжүүлж шалгана.

Apple хэрэглэгч email-ээ нуух сонголттой. `privaterelay.appleid.com` email-ийг ердийн email шиг хүлээн авна; жинхэнэ email-ийг заавал шаардахгүй. Apple бүтэн нэрийг зөвхөн эхний зөвшөөрлийн үед өгөх боломжтой тул дараагийн нэвтрэлтийн хоосон нэрээр өмнөх нэрийг дарахгүй. Google болон Apple account-ыг ижил email харагдсан гэдгээр нь автоматаар нэгтгэхгүй.

## Live шалгалт

Provider тохиргоо дууссаны дараа:

- Google-ээр анх нэвтрэх, гарах, дахин нэвтрэх, апп дахин нээхэд session сэргээх.
- Apple-ээр нэр/email хуваалцах болон Hide My Email сонголтуудыг шалгах.
- Зөвшөөрлийн popup-ийг хаахад бүртгэл үүссэн мэт харагдуулахгүй байх.
- Өөр account сонгоход өмнөх хэрэглэгчийн local library харагдахгүй байх.
- Web болон бодит iOS/Android төхөөрөмж дээр provider тус бүрийг шалгах.

Native compile болон emulator шалгалт давсан нь бодит provider-ийн тохиргоо ажилласны баталгаа болохгүй. Apple/Google-ээс буцсан бодит нэвтрэлтийг төхөөрөмж дээр дуусгаж баталгаажуулна.

## Албан ёсны эх сурвалж

- [FlutterFire social authentication](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Google Sign-In iOS plugin setup](https://pub.dev/packages/google_sign_in_ios)
- [Google Sign-In Android plugin setup](https://pub.dev/packages/google_sign_in_android)
- [Firebase Sign in with Apple](https://firebase.google.com/docs/auth/ios/apple)
- [Apple web Services ID тохиргоо](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/)
- [Auth emulator-ийн provider туршилт](https://firebase.google.com/docs/emulator-suite/connect_auth)
- [Firebase Auth Spark хэрэглээний хязгаар](https://firebase.google.com/docs/auth/limits)
