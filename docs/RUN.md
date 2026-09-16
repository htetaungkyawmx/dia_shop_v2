# ဘယ်လို run ရမလဲ

## ၁။ Backend (အရင်ဆုံး ဒါကို စပါ)

```bash
cd ~/Desktop/Claim/dia_shop_v2
docker compose up -d
```

- API → http://localhost:8080
- API စာရွက်စာတမ်း → http://localhost:8080/swagger-ui.html
- Database → localhost:5433

အလုပ်လုပ်မလုပ် စစ်ရန် —

```bash
curl http://localhost:8080/actuator/health
```

Log ကြည့်ရန် `docker compose logs -f api`၊ ရပ်ရန် `docker compose down`။

**အကုန်လုံး အလုပ်လုပ်မလုပ် တစ်ခါတည်း စစ်ချင်ရင်:**

```bash
./scripts/smoke-test.sh http://localhost:8080
```

---

## ၂။ Web app (အလွယ်ဆုံး)

```bash
cd app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## ၃။ Admin panel

```bash
cd admin
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Login — `admin@diashop.com` / `Admin@12345`

---

## ၄။ Android emulator

Emulator ထဲက `localhost` ဆိုတာ emulator ကိုယ်တိုင်ကို ညွှန်းတာမို့ **`10.0.2.2`** သုံးရပါမယ်။

```bash
flutter emulators --launch Medium_Phone_API_36.1
cd app
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## ၅။ iPhone အစစ်နဲ့ စမ်းရန်

ဖုန်းက Mac ကို wifi ကနေ ချိတ်ရမှာမို့ Mac ရဲ့ LAN IP သုံးပါ —

```bash
ipconfig getifaddr en0        # ဥပမာ 192.168.0.230
```

### နည်းလမ်း (က) — Safari နဲ့ web app ဖွင့် (Apple account မလို ✅)

```bash
cd app
flutter build web --release --dart-define=API_BASE_URL=http://192.168.0.230:8080
cd build/web && python3 -m http.server 3000
```

ဖုန်းရဲ့ Safari မှာ `http://192.168.0.230:3000` ဖွင့် → Share → **Add to Home Screen**

### နည်းလမ်း (ခ) — native app အဖြစ် install (၇ ရက် သက်တမ်း)

Apple Developer account ($99/နှစ်) မဝယ်ဘဲ ကိုယ့်ဖုန်းမှာ စမ်းလို့ရပါတယ်။ Xcode မှာ
ကိုယ့် Apple ID ကို personal team အဖြစ် တစ်ခါထည့်ပေးရပါမယ် —

```bash
open ios/Runner.xcworkspace
```

Runner → Signing & Capabilities → Team မှာ ကိုယ့် Apple ID ရွေးပါ။ ပြီးရင် —

```bash
flutter run -d "iPhone" --dart-define=API_BASE_URL=http://192.168.0.230:8080
```

> Certificate က ၇ ရက်ပဲ ခံပါတယ်။ ပြီးရင် ပြန် run ရမယ်။ ဖောက်သည်တွေအတွက်တော့
> အပေါ်က web app (PWA) နည်းလမ်းကို သုံးပါ။

### ဖုန်းက server ကို မမြင်ရင်

- Mac နဲ့ ဖုန်း wifi တစ်ခုတည်း ဖြစ်ရမယ်
- macOS firewall က Docker ကို ခွင့်ပြုထားရမယ် (System Settings → Network → Firewall)
- `curl http://192.168.0.230:8080/actuator/health` ကို Mac ကနေ အရင်စမ်းပါ

---

## ၆။ Android release build (Play Store တင်ရန်)

```bash
cd app
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Signing key ကို `android/key.properties` မှာ ထားပါ (git ထဲ မတက်ပါဘူး)။

---

## Test တွေ run ရန်

```bash
cd backend && mvn test              # 38 test
cd app && flutter test              # 12 test
./scripts/smoke-test.sh http://localhost:8080   # 50 test
```

---

## API URL အနှစ်ချုပ်

| ဘယ်ကနေ run လဲ | `API_BASE_URL` |
|---|---|
| Chrome (Mac) | `http://localhost:8080` |
| Android emulator | `http://10.0.2.2:8080` |
| ဖုန်းအစစ် (တူညီ wifi) | `http://192.168.0.230:8080` |
| Production | `https://api.yourdomain.com` |
