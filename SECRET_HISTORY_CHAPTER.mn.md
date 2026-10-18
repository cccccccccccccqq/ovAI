> Өмнөх монгол хэлтэй standalone pilot-ийн тэмдэглэл. Одоогийн англи цуврал shared Kharkhorin flow ашиглана: [шинэ заавар](SECRET_HISTORY_ENGLISH.mn.md). Хуучин series/chapter архивлагдсан; хувийн progress устгаагүй.

# Эхний түүхэн chapter — local prototype

`seed/secret-history-chapter-1.json` нь “Тэмүжиний бага нас” цувралын эхний “Ононы эрэгт мэндэлсэн хүү” бүлгийг агуулна. Энэ хувилбарт нэг chapter нийтлэгдсэн, үлдсэн дөрөв нь төлөвлөгөө хэвээр.

## Өгүүлэмж ба эх сурвалж

- Үйл явдлын эх: *The Secret History of the Mongols* (Shorter Version), Igor de Rachewiltz-ийн орчуулга, John C. Street-ийн найруулга, 2015, §59–66; өгсөн PDF-ийн 36–38 дахь хуудас. [WWU CEDAR](https://cedar.wwu.edu/cedarbooks/4/), DOI `10.25710/31qa-rh81`.
- Монгол өгүүлэмжийг энэхүү prototype-д шинээр бичсэн. Эхийн бүрэн орчуулга, үгчилсэн аудио ном биш; үйл явдлын товч тайлбар юм. Домгийн шинжтэй дүрслэлийг эхэд өгүүлсэн зүйл гэж тусад нь тэмдэглэсэн.
- Өгсөн PDF/TXT болон `SOURCE.md` нь эх сурвалжийн материал. Тэдгээрийг энэ импортын script уншдаггүй, Firestore/Storage-д байршуулдаггүй, public asset болгоогүй.
- Өгсөн орчуулгын лиценз CC BY-NC-ND 4.0 гэж тэмдэглэгдсэн. Бүтээгдэхүүнд нийтлэх эцсийн контент, эрхийн хүрээ, түүхэн тайлбарыг редакцын болон эрхийн хяналтаар баталгаажуулна. `editorialStatus: prototype-review` энэ төлөвийг илэрхийлнэ.
- Хоолой нь `mn-MN-YesuiNeural` синтетик prototype бичлэг. Бүлгийн бодит файл 240 секунд; `scenes` нь аудиотой ижил хувилбарт хадгалагдана.

## Газрын зураг

- `onon-basin`: өргөн бүсийн төвийг 49.0, 110.6, радиусыг 120 км гэж редакцын дүрслэлд сонгосон. Түүхэн хил, айлын бууц, голын шугаман геометр, GPS маршрут биш.
- `deli-un-boldaq`: Дадал орчмын уламжлалт холбоосыг 49.03, 111.65 төвтэй, 20 км хүрээгээр баримжаална. Радиус нь судалгааны хэмжсэн алдаа биш. Эртний төрсөн газрын яг цэгийг баталж буй тэмдэглэгээ биш.
- [Хэнтий аймгийн аялал жуулчлалын Дэлүүн болдогийн тайлбар](https://travel.khentii.gov.mn/place/detail/3?mid=8) нь Дадалтай холбосон тайлбар, өөр адилтгалууд байдгийг дурдсан. Иймд байршлын итгэлцлийг `uncertain` гэж хадгалсан.
- §61–66 дахь Чекчер/Чихурху уулс, Дэй сэцэний гэрийн орчин үеийн солбицлыг энэ ажилд баталгаажуулаагүй. Тэдгээрийн цэг, холбосон зам зураагүй. Аяллын үеийн scene нь Ононы ерөнхий бүсийг контекст болгон харуулж, байршил тогтоогоогүйг тайлбарлана.

## Local emulator-д хадгалах

Эхлээд emulator-уудаа асааж, аудио үүсгэсэн байна. Зөвхөн `demo-ov-chronicles` local төсөлд ажиллана.

```sh
node scripts/seed-secret-history.mjs --validate-only
node scripts/seed-secret-history.mjs
```

MP3-ийг өөр замд үүсгэсэн бол:

```sh
node scripts/seed-secret-history.mjs --audio /absolute/path/to/narration-mn.mp3
```

Script нь аудиог `catalog/secret-history/onon-child-v1/narration-mn.mp3` Storage объектод; өгүүлэмжийг `chapters/onon-child`, цувралыг `series/temujin-childhood`, газрын тайлбаруудыг `historicalPlaces` collection-д хадгална. Давтан ажиллуулахад ижил ID-тай prototype баримтууд шинэчлэгдэнэ. Бусад түүх, хэрэглэгчийн мэдээлэл устгахгүй. Бүх файл болон өгөгдлийг шалгасны дараа бичнэ; бичсэний дараа chapter болон Storage объектын хэмжээг дахин уншиж баталгаажуулна.

Emulator-ыг `npm run emulators:start`-аар эхлүүлсэн үед хэвийн зогсооход `emulator-data` руу export хийгдэнэ. Энэ локал өгөгдөл бөгөөд өөр төхөөрөмж рүү cloud sync хийсэн гэсэн үг биш.

## Апп дээр үзэх, дахин шалгах

```sh
# Repository root, emulator-ууд ажиллаж байх үед:
npm run seed:chapter
npm run chapter:verify

# Flutter web (app/ дотор):
flutter build web --release --no-wasm-dry-run --dart-define=AUTH_MODE=emulator --dart-define-from-file=.maps-web.local.json
python3 -m http.server 8766 --bind 127.0.0.1 --directory build/web
```

`http://127.0.0.1:8766/#/history/onon-child` эсвэл Steppe-ийн эхний chapter card-ийг нээнэ. Play/pause, seek, bookmark, map-аа чөлөөтэй үзэх, газрын зургийг аудиотой дагуулах сонголттой. Хуудас руу буцаж ороход тухайн local account-ийн progress-ийг cache биш Firestore server-оос авна. Anonymous local account нь энэ browser-ийн Firebase session-д тогтоно; live Google хэрэглэгчтэй нэгтгээгүй.

`chapter:verify` нь жинхэнэ Firebase client SDK-аар chapter/series/газруудыг уншиж, Storage аудионы SHA-256-г эх файлтай тулгана. Callable-аар 1:32 ба bookmark хадгалаад шинэ client session-ээс ижил UID-ээр дахин уншина. Өөр account-ийн уншилт болон client-ийн шууд content бичилтийг хориглож байгааг шалгана. Зөвхөн өөрийн үүсгэсэн test account/progress-ийг цэвэрлэнэ; нийтэлсэн chapter-ийг устгахгүй.

Аудиог шинээр бэлдэх шаардлагатай үед Python venv-д `edge-tts==7.3.1`, мөн `ffmpeg`, `ffprobe` хэрэгтэй:

```sh
python scripts/generate-secret-history-audio.py --source seed/secret-history-chapter-1.json --output app/assets/audio/secret-history/onon-child-v1/narration-mn.mp3
```

Энэ authoring command нь зөвхөн шинээр бичсэн өгүүлэмжийг online синтетик хоолойн service-д явуулна. Апп ажиллах үед TTS дууддаггүй. Scene бүрийн бодит бичлэгийг timeline-д тааруулж, бүх аудиог 240 секунд болгон нийлүүлнэ. Үүсгэсэн `.production.json` нь эх текст/аудионы hash, voice, scene бүрийн хугацааны тохируулгыг тэмдэглэнэ. Контентыг нийтэлсний дараа засахдаа contentVersion болон Storage замыг хамт өсгөнө.

## Browser session сэргээх тохиргоо

Web release дээр Firebase Auth-ийн local session-ийг сэргээхээс өмнө emulator endpoint-ийг тохируулна. `web/index.html` дахь chapter-д зориулсан public Firebase JS bootstrap зөвхөн `ov-history-local` / `demo-ov-chronicles` app-ийг loopback Auth emulator-д холбодог. Dart нь түүнийг `Firebase.app`-аар ашиглаж, Firestore/Functions/Storage-ийг мөн local endpoint-ууд руу чиглүүлнэ. Үндсэн Google/Apple Auth gateway-ийг өөрчлөхгүй. Энэ дараалал нь browser refresh-ийн дараах local UID болон сонссон хугацааг хадгалахад шаардлагатай.
