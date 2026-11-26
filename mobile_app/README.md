# Employee Tasks — Android App

ဒါက `employee_tasks_dashboard` အတွက် Flutter Android client ပါ။ Web dashboard ရဲ့ အပြင်အဆင်နဲ့ ဒေတာကိုပဲ သုံးထားတယ်။ **Firebase မသုံးပါဘူး** — လိုအပ်တဲ့အခါ server က `json_data_records` ထဲက JSON ကို တောင်းယူပြီး ဖုန်းထဲ cache လုပ်တယ်။ Report ကိုတော့ Telegram ဆီ တိုက်ရိုက်ပို့တယ်။

---

## ၁။ အရင် လိုအပ်တာတွေ စစ်ပါ

ဒီစက်မှာ ရှိပြီးသားတွေ —

| အရာ | တည်နေရာ / မှတ်ချက် |
| --- | --- |
| Flutter | `/home/mr_robot/.flutter/bin/flutter` (Flutter 3.50.1, Dart 3.14.0) |
| Android SDK | `/home/mr_robot/Android/Sdk` |
| Java | `/home/mr_robot/.android-studio/jbr` (Java 17) |

PATH ထဲ မပါရင် တစ်ကြိမ်တည်း ဒီလို run ပါ:

```bash
export PATH="$HOME/.flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export JAVA_HOME="$HOME/.android-studio/jbr"
flutter doctor
```

`flutter doctor` မှာ Android toolchain နဲ့ Network resources အဆင်ပြေနေရင် နောက်ဆက်တွဲ ဆက်လုပ်လို့ရပါပြီ။

> Project မှာ `android.builder.sdkDownload=false` ထားထားတယ်။ ဒါက AGP ကိုယ်တိုင် `sdkmanager` ပြန်ခေါ်ပြီး package ပြန်ဆွဲတာ မလုပ်အောင် ကာကွယ်တာပါ။ SDK package တွေ (NDK 28.2, platform 34/35/36/37) ကတော့ ရှိပြီးသားဖြစ်ရမယ်။

---

## ၂။ Project ထဲဝင်ပြီး dependencies ရယူပါ

```bash
cd /home/mr_robot/Desktop/employee_tasks_dashboard/mobile_app
flutter pub get
flutter analyze        # "No issues found" ဖြစ်ရမယ်
flutter test           # 13 tests pass ဖြစ်ရမယ်
```

---

## ၃။ Server ဘက်မှာ လုပ်ရမယ့်အရာ

`.env` ထဲမှာ mobile အတွက် read-only token ထည့်ပါ (အနည်းဆုံး စာလုံး ၃၂ လုံး):

```bash
openssl rand -hex 32      # token အသစ်ထုတ်ဖို့
```

```dotenv
MOBILE_API_TOKEN=ဒီနေရာမှာ_token_ထည့်ပါ
```

Environment ပြောင်းတာမို့ container ကို **recreate** လုပ်ရပါမယ် — `docker compose restart` နဲ့ မဝင်ပါဘူး:

```bash
cd /home/mr_robot/Desktop/employee_tasks_dashboard
docker compose up -d --force-recreate web-dashboard
```

Server ရဲ့ endpoint နှစ်ခုက ဒီလိုပါ:

| Endpoint | ပြန်ရတာ |
| --- | --- |
| `GET /api/mobile/dates` | `{"dates": ["YYYY-MM-DD", ...]}` |
| `GET /api/mobile/data/<date>` | `json_data_records/<date>.json` ထဲက အတိုင်း |

`X-Mobile-Token` header မပါရင် **401** ပြန်တယ်။ Token မထည့်ထားရင် endpoint တွေ ပိတ်ထားတာနဲ့ အတူတူပါပဲ။

---

## ၄။ App ထဲမှာ Settings ဖြည့်ပါ

App ကို ဖွင့်ပြီး ညာဘက်အပေါ်က ⚙️ (Settings) ကို နှိပ်ပါ:

1. **Dashboard server URL** — ဥပမာ `https://dashboard.example.com` (nginx က port 443 မှာ ရှိတယ်)
2. **Mobile API token** — အပေါ်က `MOBILE_API_TOKEN` နဲ့ တူတူ
3. **Sync from server** ကို နှိပ်ပါ (app ဖွင့်တိုင်း အလိုအလျောက်လည်း sync လုပ်တယ်)

Report ပို့ချင်ရင်တော့ ဒီအချက်အလက်တွေ ထပ်ဖြည့်ပါ:

4. **Report chat ID** — report လက်ခံမယ့် Telegram chat/user ID (ဂဏန်း)
5. **Your Telegram username** (optional) — report မှာ author အမည်အဖြစ် ပြမယ်
6. **Telegram bot token** — report ပို့မယ့် bot ရဲ့ token

---

## ၅။ APK ထုတ်နည်း (ဘယ်ကစပြီး ဘာရိုက်ရမလဲ)

### Debug APK (စမ်းသပ်ဖို့ အဆင်ပြေဆုံး)

```bash
cd /home/mr_robot/Desktop/employee_tasks_dashboard/mobile_app
export PATH="$HOME/.flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
flutter build apk --debug
```

ထွက်လာတဲ့ file:

```
mobile_app/build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK

```bash
flutter build apk --release
```

ထွက်လာတဲ့ file:

```
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

> ⚠️ လက်ရှိ `android/app/build.gradle.kts` မှာ release က **debug key နဲ့ လက်မှတ်ထိုးထားတာ** ဖြစ်ပါတယ်။ Play Store တင်ဖို့ဆိုရင် ကိုယ်ပိုင် keystore ဖန်တီးပြီး `signingConfigs` ထည့်ပြီး ပြန်ဆောက်ရပါမယ်။

### တိုက်ရိုက် ဖုန်းထဲ install / run

```bash
adb devices                       # ဖုန်း connected ဖြစ်နေရမယ်
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# ဒါမှမဟုတ် Flutter ကနေတိုက်ရိုက်:
flutter run --release
flutter install
```

---

## ၆။ ဒေတာ ဘယ်လိုရောက်လဲ

```
Server json_data_records ──(GET /api/mobile/data/<date>)──▶ App ──▶ ဖုန်းထဲ cache
App ──(sendMessage)────────────────────────────────────────▶ Telegram Bot API
```

- App ဖွင့်တဲ့အခါ / ရက်ပြောင်းတဲ့အခါ / sync button / pull-to-refresh တို့မှာ server ကို တောင်းတယ်။
- ပြန်ရတဲ့ JSON ကို `SharedPreferences` ထဲ သိမ်းပြီး UI က အဲဒီ cache ကပဲ ဖတ်တယ် — network မရှိရင်လည်း အရင်ဒေတာ ပြနေမယ်။
- Report ပို့တာက bot ရဲ့ `notify_report_received` ပုံစံအတိုင်း Telegram ဆီ တိုက်ရိုက် message ပို့တာပါ။ ဒါက **dashboard JSON ကို ရေးတာ မဟုတ်ပါဘူး** — JSON မှာ မှတ်ချင်ရင် Telegram bot ရဲ့ `/report` ကမှ ရေးပေးတယ်။
- **Server က ကိုယ်တိုင် push လုပ်တာ မရှိတော့ပါဘူး** — အသစ်ရေးထားတဲ့ task က app ဖွင့်/refresh လုပ်မှ ရောက်မယ်။

---

## ၇။ လုံခြုံရေး

- Bot token က အကန့်အသတ်မရှိပါဘူး — ထုတ်ယူသွားရင် bot ကို လုံးဝ ထိန်းချုပ်နိုင်တယ်။ App ထဲ source မှာ မထည့်ဘဲ Settings ကနေပဲ ထည့်စေတယ်၊ ဖုန်းထဲမှာပဲ သိမ်းတယ်၊ log မှာ မရေးပါဘူး။ **သီးခြား low-privilege reporting bot သုံးပြီး token ကို ပုံမှန် rotate လုပ်ပါ။**
- `MOBILE_API_TOKEN` ကိုလည်း လျှို့ဝှက်ထားပါ — ဒါက နေ့စဉ် အချက်အလက်အားလုံးကို ဖတ်ခွင့်ပေးတယ်။

---

## ၈။ အခက်အခဲ တွေ့ရင်

| လက္ခဏာ | ဖြေရှင်းနည်း |
| --- | --- |
| `401` ပြတယ် | App Settings ထဲက token နဲ့ server `.env` ထဲက `MOBILE_API_TOKEN` တူမတူ စစ်ပါ |
| `flutter doctor` မှာ SDK မတွေ့ | `export ANDROID_HOME=$HOME/Android/Sdk` ထားပြီး ပြန်စစ်ပါ |
| Gradle က NDK/platform ပြန်ဆွဲနေတယ် | `android/gradle.properties` ထဲက `android.builder.sdkDownload=false` ကို ဖြေထားမိမိ စစ်ပါ |
| ထူးဆန်းတဲ့ build error | `flutter clean && flutter pub get && flutter build apk --debug` ပြန်လုပ်ပါ |
| 404 | Server URL မှန်မမှန်၊ nginx က 443 မှာ အလုပ်လုပ်နေလား စစ်ပါ |

---

## ၉။ အတည်ပြုချက် (ဒီ project မှာ တကယ်လုပ်ခဲ့တာ)

```
flutter analyze       → No issues found
flutter test          → 13 tests passed
flutter build apk     → BUILD_EXIT=0, app-debug.apk ထွက်ပြီး
python unittest       → 30 ထဲ 29 pass (1 က အရင်ကတည်းက ရှိနေတဲ့ fixture ပြဿနာ)
```
