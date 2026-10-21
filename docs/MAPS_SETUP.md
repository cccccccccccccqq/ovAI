# Google Maps тохиргоо

2026-10-17-нд өгсөн API key-ээр localhost дээр Flutter аппын Google terrain map,
дөрвөн газрын marker ачаалж байгааг шалгасан. Marker сонгоход тухайн газрын
сонголт апп дотор шинэчлэгдэж, browser console-д map алдаа гараагүй. Flutter
web release build, 81 тест, iOS simulator debug build амжилттай давсан. iPhone
17 Pro Simulator дээр шинэ аппыг суулгаж, Steppe нүүрэнд бодит Google Maps,
дөрвөн marker ачаалсныг дэлгэцээр шалгасан. Газрын нэр болон marker сонгоход
камер, газрын карт, сонголт хамт шинэчлэгдэнэ. Built iOS app-ийн key тохиргоо
болон Maps SDK/plugin symbol холбоосыг key-г хэвлэхгүйгээр шалгасан.
Иймээс энэ key-г зөвхөн IP байршил тогтоох
үйлчилгээнд зориулсан гэж үзэх үндэсгүй. Одоогийн Google account-аар key-ийн
эзэмшигч project болон restrictions мэдээллийг уншихад 403 буцсан тул Console
дахь зөвшөөрөл, quota, төлбөрийн төлөвийг баталгаажуулаагүй. API enable болон
billing өөрчлөлт автоматаар хийгээгүй.

## Геолокаци ба газрын зураг

[Geolocation API](https://developers.google.com/maps/documentation/geolocation/overview)
нь үүрэн холбооны цамхаг, Wi-Fi мэдээллээс latitude/longitude, accuracy radius
буцаадаг; IP ашиглах fallback тохиргоо ч байдаг. Энэ үйлчилгээ газрын зургийн
tile дүрслэх SDK-ээс тусдаа. Аппын одоогийн байршлын үйлдэл нь хэрэглэгчийн
зөвшөөрөлтэй browser/device location үйлчилгээг ашиглана. Maps JavaScript API,
Maps SDK for iOS, Maps SDK for Android нь газрын зураг дүрслэнэ.

## Газрын координатын эх сурвалж

2026-10-17-нд © OpenStreetMap contributors-ийн нийтэлсэн газрын мэдээлэлтэй
дөрвөн тэмдэглэгээг тулгасан. Төвхөний хуучин demo цэг хийдээс ойролцоогоор
594 м зөрүүтэй байсан тул Flutter catalog болон Firebase seed-д
`47.0129679, 102.2558901` болгон зассан.

- [Төвхөн хийд — OSM node 499158584](https://www.openstreetmap.org/node/499158584).
  [UNESCO-ийн 2003 оны техникийн баримт](https://whc.unesco.org/document/1410),
  PDF-ийн 21-р хуудасны координат мөн энэ орчимд байна.
- [Эрдэнэ Зуугийн хүрээ — OSM way 397170801](https://www.openstreetmap.org/way/397170801).
  Одоогийн цэг хийдийн хүрээнд байна.
- [Хархорин хот — OSM way 1453173582](https://www.openstreetmap.org/way/1453173582).
  Одоогийн тэмдэглэгээ хотыг заана; Хархорумын туурийн хаалга гэж үзэхгүй.
- [Улаан цутгалан — OSM node 2078132147](https://www.openstreetmap.org/node/2078132147).
  Одоогийн цэг нийтэлсэн хүрхрээний цэгээс ойролцоогоор 20 м зайтай.

Газрын хооронд татсан шугам нь аяллын ерөнхий дүрслэл. Автомашины зам,
нэвтрэх хаалга болон явган маршрутыг энэ шугамаас тодорхойлохгүй.

## Local key файл

Workspace-ийн үндсэн `.env.maps.local` файлд key хадгална. Энэ файлыг Git-д
оруулахгүй. `GOOGLE_MAPS_API_KEY` нь гурван платформын нийтлэг fallback;
платформ тус бүрийн key байвал дараах нэрээр тохируулж болно:

```dotenv
GOOGLE_MAPS_API_KEY=<shared-development-key>
GOOGLE_MAPS_WEB_KEY=<web-key>
GOOGLE_MAPS_IOS_KEY=<ios-key>
GOOGLE_MAPS_ANDROID_KEY=<android-key>
```

Ашиглахгүй мөрийг хасна. Key утгыг terminal command аргумент болон чатад
дахин оруулах шаардлагагүй; local файлаа editor-оор засна. Дараа нь repository
root-оос ажиллуулна:

```sh
node scripts/configure-maps.mjs
```

Script нь утгыг execute хийхгүй, формат шалгаад дараах Git-д орохгүй файлуудыг
`0600` permission-тэй үүсгэнэ. Key-г log-д хэвлэхгүй.

- `app/.maps-web.local.json`, `app/.maps-ios.local.json`, `app/.maps-android.local.json`
  — Flutter `MAP_PROVIDER=google`, `GOOGLE_MAPS_API_KEY` compile-time тохиргоо.
- `app/ios/Flutter/Maps.local.xcconfig` — iOS native SDK key.
- `app/android/maps.local.properties` — Android native SDK key.

Эх `.env.maps.local` файлын permission-ийг мөн `0600` болгоно. Generated файлуудыг
гараар өөрчлөхийн оронд эх файлаа засаад script-ээ дахин ажиллуулна.

## Ажиллуулах

`app` хавтас дотор:

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=.maps-web.local.json
flutter run -d <ios-device-id> --dart-define-from-file=.maps-ios.local.json
flutter run -d <android-device-id> --dart-define-from-file=.maps-android.local.json
```

Google Maps-ийг ашиглах нь Firebase Auth-ийн сонголтоос тусдаа. Default app live
Auth ашигладаг. Local Firebase Auth emulator хэрэгтэй бол тухайн run команддаа
`--dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator` нэмж, emulator-уудаа урьдчилан асаана.

```sh
flutter run -d chrome --dart-define-from-file=.maps-web.local.json --dart-define=BACKEND_MODE=emulator --dart-define=AUTH_MODE=emulator
```

Key-ийн файл эсвэл define байхгүй build нь одоогийн OpenStreetMap сонголтыг
ашиглаж болно. iOS xcconfig include optional, Android placeholder хоосон fallback
утгатай тул map key оруулаагүй build configuration уншихад алдаа өгөхгүй.
Steppe нүүр хуудасны газрын зураг онлайн үед Google Maps ашиглана. Газрын
chip эсвэл marker сонгоход сонголт, camera байрлал хамт шинэчлэгдэнэ. Offline
үед өмнөх illustrated зураг fallback болж ажиллана. **Open field map** товчоор
том газрын зургийн дэлгэцийг нээнэ.

## Платформын Google Cloud тохиргоо

[Flutter-ийн албан ёсны Google Maps тохиргоо](https://developers.google.com/maps/flutter-package/config)
нь платформ тус бүрт өөр key, application restrictions ашиглахыг зөвлөдөг.

| Платформ | Шаардлагатай API | Application restriction |
| --- | --- | --- |
| Web | Maps JavaScript API | Website referrer: ашиглах localhost origin болон production domain |
| iOS | Maps SDK for iOS | Bundle ID: `mn.ov.ovChronicles` |
| Android | Maps SDK for Android | Package: `mn.ov.ov_chronicles`, signing certificate SHA-1 |

Платформ тус бүрийн key дээр зөвхөн хэрэгтэй API-г зөвшөөрнө. IP restriction
нь server хүсэлтэд тохиромжтой; browser/mobile app-д дээрх application
restrictions тохирно. Client app дотор орох key нь build-ээс харагдах боломжтой
учраас restriction нь хамгаалалтын үндсэн хэсэг юм. Local файл Git-д орохгүй
байх нь үүнийг орлохгүй.

Web болон iOS Simulator дээр газрын зураг бодитоор ачаалсныг шалгасан.
Android дээрх runtime map-ийг хараахан шалгаагүй. API enable, key restriction,
Maps project-ийн billing/quota-ийн тохиргоог эзэмшигч Google Cloud Console-оос
шалгах шаардлагатай. Maps billing болон Firebase Blaze нь тусдаа тохиргоо;
энэ ажил Firebase billing plan-ийг өөрчлөөгүй.

iOS `AppDelegate` нь Info.plist доторх `GMSApiKey`-г авч, plugin registration-оос
өмнө `GMSServices.provideAPIKey` дуудна. Android Manifest нь
`com.google.android.geo.API_KEY` metadata-аар local property-г SDK-д өгнө.
Апп iOS 15-аас дэмждэг тул `google_maps_flutter_ios_sdk9` implementation сонгосон;
энэ нь Google Maps SDK 9.x-ийг ашигладаг.

API key-г сольсны дараа helper-ээ дахин ажиллуулж app-аа бүрэн restart/rebuild
хийнэ; compile-time define, native config өөрчлөлт hot reload-оор солигдохгүй.
