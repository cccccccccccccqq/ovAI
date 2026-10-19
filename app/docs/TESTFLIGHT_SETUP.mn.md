# Deploy ба TestFlight — алхам алхмаар

Зорилго: backend болон web-ийг `ov-ai-5ae61` дээр гаргаж, iOS build-ийг TestFlight-ээр Энхжингийн утсанд суулгах.

iOS build-ийг GitHub Actions-ийн macOS runner хийнэ (`.github/workflows/ios-testflight.yml`). Тиймээс Xcode, Mac, certificate файл шаардлагагүй. Xcode нь App Store Connect API key-ээр signing certificate болон profile-ийг өөрөө үүсгэнэ.

| Хэн | Юу | Хугацаа |
|---|---|---|
| Энхжин | A. Merge хийх, deploy хийх | ~10 мин |
| Амраа | B. Apple Developer ба App Store Connect, GitHub secrets | ~20 мин |
| Энхжин | C. Firebase Console тохиргоо | ~10 мин |
| Хэн ч | D. Workflow ажиллуулах → TestFlight | ~30 мин (ихэнх нь хүлээлт) |

---

## A. Deploy (Энхжин)

1. GitHub дээр **#2**-ыг merge хийхдээ **Delete branch**-ийг дарна. Ингэхэд #3-ийн base автоматаар `main` болж солигдоно. Дараа нь **#3**-ыг merge хийнэ.
2. Local дээр:
   ```bash
   git checkout main && git pull
   npx firebase-tools login          # enkhjin@geret.mn
   ./scripts/deploy-prod.sh
   ```
   Script нь Functions болон Flutter-ийн тест, analyze-ийг ажиллуулж, web build хийгээд `functions, firestore:rules, storage, hosting`-ийг deploy хийнэ. Flutter 3.41.7 шаардлагатай.
3. Шалгах:
   - https://ov-ai-5ae61.web.app нээгдэх ёстой
   - https://ov-ai-5ae61.web.app/privacy.html нээгдэх ёстой
   - `npx firebase-tools functions:list --project ov-ai-5ae61` жагсаалтад `deleteAccount` байх ёстой

## B. Apple тал (Амраа, Team `W94G6F573L` — IO Technology LLC)

1. **App ID:** [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → `mn.ov.ovChronicles` (байхгүй бол **+** дарж App ID үүсгэнэ). Capabilities хэсэгт дараах хоёрыг асаана:
   - ☑ **Sign in with Apple**
   - ☑ **App Attest**
2. **App бүртгэх:** [App Store Connect](https://appstoreconnect.apple.com) → Apps → **+ New App**
   - Platform: iOS
   - Name: `öv AI` (давхардвал `öv AI: Mongolian History`)
   - Primary language: English
   - Bundle ID: `mn.ov.ovChronicles`
   - SKU: `ovai-ios`
3. **API key:** App Store Connect → Users and Access → **Integrations** → App Store Connect API → Team Keys → **Generate API Key**
   - Name: `GitHub TestFlight`
   - Access: **Admin**. Certificate болон profile автоматаар үүсгэхэд энэ эрх хэрэгтэй.
   - `.p8` файлыг **нэг л удаа** татаж авах боломжтой. **Key ID** болон хуудасны дээд талын **Issuer ID**-г тэмдэглэж авна.
4. **GitHub secrets:** repo-гийн Settings → Secrets and variables → Actions → **New repository secret**. Эсвэл terminal-аас:
   ```bash
   gh secret set APP_STORE_CONNECT_KEY_ID    -R cccccccccccccqq/ovAI   # Key ID
   gh secret set APP_STORE_CONNECT_ISSUER_ID -R cccccccccccccqq/ovAI   # Issuer ID
   gh secret set APP_STORE_CONNECT_KEY_P8    -R cccccccccccccqq/ovAI < AuthKey_XXXXXXXXXX.p8
   gh secret set GOOGLE_MAPS_IOS_KEY         -R cccccccccccccqq/ovAI   # заавал биш; байхгүй бол OpenStreetMap
   ```
   `.p8` файлыг chat, имэйл болон Git-ээр бүү дамжуул.
5. **Энхжинг тестер болгох:** Users and Access → **+** → Энхжингийн Apple ID имэйл, role нь Developer эсвэл Marketing. Энхжин урилгыг имэйлээсээ зөвшөөрнө.
6. **Sign in with Apple key (token revoke-д):** Certificates, IDs & Profiles → Keys → **+** → ☑ Sign in with Apple → Configure → Primary App ID `mn.ov.ovChronicles`. Үүссэн `.p8`, Key ID-г Энхжинд найдвартай замаар өгнө. Энэ нь C-3 алхамд хэрэгтэй.

## C. Firebase Console (Энхжин, `ov-ai-5ae61`)

1. **Team ID:** Project settings → Your apps → **Ov AI iOS** → Team ID = `W94G6F573L`.
2. **App Check:** App Check → Apps → Ov AI iOS → **App Attest** → Register.
   > Backend-ийн callable-ууд App Check шаарддаг. Энэ алхмыг алгасвал TestFlight build дээр нэвтэрсний дараах түүх хадгалах, явц, account устгах функцүүд ажиллахгүй.
3. **Apple нэвтрэлт:** Authentication → Sign-in method → **Apple** → Enable.
   - OAuth code flow хэсэгт Team ID `W94G6F573L`, B-6-ийн Key ID болон private key-г оруулна. Апп account устгах үед Apple токеныг revoke хийхэд энэ хэрэгтэй.
   - Services ID зөвхөн web/Android-д хэрэгтэй тул одоогоор хоосон үлдээж болно.
4. **Google нэвтрэлт:** аль хэдийн идэвхтэй. iOS client `765364993612-buhd7…` нь `Info.plist`-тэй таарч байгаа.

## D. TestFlight build

1. GitHub → **Actions** → **iOS TestFlight** → **Run workflow** (`main`). Эсвэл:
   ```bash
   git tag ios-v1.0.0-1 && git push origin ios-v1.0.0-1
   ```
2. Ойролцоогоор 20 минут ажиллана: тест → build → archive → TestFlight руу upload. Build number нь workflow-ийн run number.
3. App Store Connect → TestFlight дээр build "Processing" төлөвт 10–30 минут байна. Export compliance-ийн асуултыг `ITSAppUsesNonExemptEncryption = false` тохиргоо автоматаар хариулна.
4. TestFlight → **Internal Testing** → **+** group (жишээ нь `Team`) → Testers хэсэгт Энхжинг нэмэх → build-ээ group-т нэмэх. Internal тестэд Apple-ийн review шаардлагагүй.
5. Энхжин: iPhone дээр **TestFlight** апп суулгана (App Store-оос) → урилгын имэйл эсвэл TestFlight дотроос **öv AI** → Install.

## Алдаа гарвал

| Шинж тэмдэг | Шалтгаан → засвар |
|---|---|
| `Missing repository secrets` | B-4 алхмын secret дутуу байна |
| `No Accounts` / `No signing certificate` | API key-ийн Access нь Admin биш байна → Admin эрхтэй key шинээр үүсгэнэ |
| `Provisioning profile doesn't include the Sign in with Apple capability` | B-1-ийн capability асаагүй байна |
| `No suitable application records were found` | B-2-ийн App Store Connect app бүртгэгдээгүй эсвэл bundle ID зөрж байна |
| Апп дотор "Sign-in provider is not configured" | C-3 Apple provider асаагүй байна |
| Нэвтэрсний дараа түүх хадгалагдахгүй | C-1, C-2 App Check бүртгэгдээгүй байна |
