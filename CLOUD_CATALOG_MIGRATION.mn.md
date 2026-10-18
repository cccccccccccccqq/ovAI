# Cloud catalog шилжүүлэх — ov-ai-5ae61

Одоогийн local emulator-ийн бэлдсэн контентыг canonical seed болон app assets-аас `ov-ai-5ae61` project руу оруулна. Emulator-ийн Auth account, хэрэглэгчийн library, bookmark, progress, хиймэл demo хэрэглэгчийг cloud руу хуулахгүй. Шинэ cloud хэрэглэгч өөрийн Google/Apple account-аар ороход өөрийн UID-тай шинэ library үүснэ.

## Орох өгөгдөл

`seed/cloud-catalog-manifest.json` нь credential агуулаагүй, SHA-256-тай бүрэн жагсаалт:

| Төрөл | Тоо | Cloud байрлал |
| --- | ---: | --- |
| Одоогийн 4 demo газар + Onon | 5 | Firestore `sites` |
| Demo 11 + англи 6 өгүүлэмж | 17 | Firestore `storyTemplates` |
| 4 минутын дараалсан англи chapter | 5 | Firestore `chapters` |
| Temüjin: The Early Years цуврал | 1 | Firestore `series` |
| Түүхэн ерөнхий бүс | 2 | Firestore `historicalPlaces` |
| Эх сурвалж, citation metadata | 9 | Firestore `sources` (admin read) |
| Аудио | 68 | Storage `catalog/audio/{voice}/{template}.m4a` |
| Зураг | 4 | Storage `catalog/images` |

Нийт: **39 document, 72 media object, 60,262,788 byte**. Аудионы 24 нь англи түүхийн 6 өгүүлэмж × Samantha/Daniel/Karen/Moira бөгөөд тус бүр 240 секунд. Номын бүтэн PDF болон extracted TXT cloud руу орохгүй. Citation нь reader дээрх story document-д давхар хадгалагдана; эх сурвалжийн дэлгэрэнгүй metadata нь `sources` дотор байна.

## Шаардлага

- Target project: `ov-ai-5ae61`, project number `765364993612`.
- Firestore `(default)` database болон `ov-ai-5ae61.firebasestorage.app` bucket үүссэн байх.
- Cloud Functions/Storage-д шаардлагатай billing тохиргоог project owner хийсэн байх. Скрипт billing account холбохгүй.
- IAM эрхтэй Google login: Application Default Credentials эсвэл одоо нэвтэрсэн Firebase CLI account.
- Emulator routing environment variable-ууд unset байх; cloud importer тэдгээрийг илрүүлбэл зогсоно.
- Cloud rules, indexes, Functions болон Flutter-ийн cloud Firebase configuration-ийг тусад нь deploy/build хийнэ. Cloud deploy-д `firebase.cloud.json` config, `--project=ov-ai-5ae61` explicit target хэрэглэнэ. `firebase.json` нь emulator тохиргоогоо хадгалсан; local startup/test script нь `demo-ov-chronicles` target-аа explicit заадаг. `.firebaserc`-ийн default cloud болсон ч emulator command-ууд cloud руу бичихгүй. Энэ importer зөвхөн catalog оруулдаг.

## Local preflight — cloud-д холбогдохгүй

Repo root: `/Users/amarmurunmandakh/HackathonApp`.

```sh
npm run cloud:catalog:plan -- --manifest-out=seed/cloud-catalog-manifest.json
npm run test:cloud-catalog
```

Plan нь файлуудын hash, M4A/JPEG header, англи хэл, chapter → template холбоос, source section, map region, 4 минутын production report, бүх voice-ийн файлыг шалгана. Manifest өөрчлөгдвөл дараах apply command-ийн SHA-256-г шинээр гарсан утгаар шинэчилнэ.

## Cloud inspection — зөвхөн уншина

```sh
npm run cloud:catalog -- --inspect \
  --project=ov-ai-5ae61 \
  --bucket=ov-ai-5ae61.firebasestorage.app \
  --firebase-cli-auth
```

`--firebase-cli-auth`-ийг орхивол стандарт ADC ашиглана. Firebase CLI credential-ийг зөвхөн суусан CLI-ийн internal token refresh-ээр memory дотор ашигладаг; token/key-г repo, env файл, manifest, output-д бичихгүй. CLI API хувилбараас хамаарах энэ сонголт нь pinned `firebase-tools` хувилбарт зориулагдсан.

Existing document-ийн бүх authored field, existing media-ийн byte хэмжээ, content type, татаж авсан SHA-256 ижил, мөн Firebase download token бэлэн бол `identical` гэж үзээд алгасана. Өөр өгөгдөлтэй ижил ID байвал `conflict` гэж жагсаагаад **cloud write эхлүүлэхгүй**. Хэрэглэгчийн өөр collection-уудыг scan хийхгүй, устгахгүй, солихгүй.

## Apply — зөвхөн дутуу контент нэмнэ

```sh
npm run cloud:catalog -- --apply \
  --project=ov-ai-5ae61 \
  --bucket=ov-ai-5ae61.firebasestorage.app \
  --manifest-sha256=6ea0ed6494b1363be3df1a63fe30efcc65b03fff52edfc46ced12574b9451b2f \
  --firebase-cli-auth
```

Скрипт өөр project/bucket хүлээж авахгүй. Зөвхөн `sites`, `storyTemplates`, `chapters`, `series`, `historicalPlaces`, `sources` top-level document болон `catalog/audio`, `catalog/images` object бичнэ.

Эхлээд бүх media-г `ifGenerationMatch=0` нөхцөлөөр create хийж, буцааж татан hash шалгана. Зөвхөн шинэ public catalog object-д `firebaseStorageDownloadTokens` UUID metadata үүсгэж Flutter-ийн `getDownloadURL()`-тай нийцүүлнэ. Token-ийг output/manifest-д гаргахгүй; existing object-ийн token-ийг солихгүй. Existing object token-гүй байвал conflict гэж зогсоно. Дараа нь Firestore-ийн бүх missing document-ийг `exists:false` нөхцөлтэй **нэг atomic commit**-оор publish хийнэ. Ингэснээр дараах эрсдэлээс хамгаална:

- Шалгасны дараа target контент өөрчлөгдвөл overwrite хийхгүй, алдаа өгнө.
- Нэг recording дутуу бол шинэ narration document publish хийхгүй.
- Дунд нь тасарвал upload хийгдсэн зарим media байж болно; дараагийн run ижил файлыг таньж, missing хэсгээ үргэлжлүүлнэ.
- Existing target document-ийн server timestamp болон нэмэлт top-level field өөрчлөгдөхгүй.

## Бүрэн readback

```sh
npm run cloud:catalog -- --verify \
  --project=ov-ai-5ae61 \
  --bucket=ov-ai-5ae61.firebasestorage.app \
  --firebase-cli-auth
```

Verify нь 39 document-ийн authored field бүр болон cloud-оос татсан 72 media object-ийн SHA-256-г шалгана. Дутуу эсвэл өөр өгөгдөлтэй байвал амжилт гэж тайлагнахгүй. Энэ нь cloud дотор бодит өгөгдөл байгааг шалгах алхам; дараа нь Flutter-ийг cloud горимд нээж reader/player, chapter path болон хэрэглэгчийн bookmark/progress-ийг тусад нь шалгана.

Энэ файл болон tooling бэлэн болсон нь cloud migration гүйцэтгэсэн гэсэн үг биш. Apply/verify-ийн бодит үр дүнг deployment явцын тайланд тэмдэглэнэ.
