# Employee Tasks — Android App

ဒါက `employee_tasks_dashboard` အတွက် Flutter Android client ပါ။ Web dashboard ရဲ့ အပြင်အဆင်နဲ့ ဒေတာကိုပဲ သုံးထားတယ်။ **Firebase မသုံးပါဘူး** — လိုအပ်တဲ့အခါ server က `json_data_records` ထဲက JSON ကို တောင်းယူပြီး ဖုန်းထဲ cache လုပ်တယ်။ Report ပို့တဲ့ feature မပါတော့ဘူး — server က ပြန်ပို့တဲ့ Engineer Report ကိုပဲ ဖတ်ပြတယ်။

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
flutter test           # 21 tests pass ဖြစ်ရမယ်
```

---

## ၃။ Emulator မှာ စမ်းနည်း (စက်ပေါ်မှာ တကယ်စမ်းပြီး အဆင်ပြေတာ)

ဒီစက်မှာ AVD ရှိပြီးသားပါ — `Medium_Phone_API_37.0` (Android 17, x86_64, Google Play image)။ `/dev/kvm` လည်း အဆင်ပြေနေတယ်။ အသစ် download လုပ်စရာ မလိုပါဘူး။

### Emulator ဖွင့်ပါ

```bash
export PATH="$HOME/.flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export JAVA_HOME="$HOME/.android-studio/jbr"

flutter emulators                                  # AVD စာရင်းပြတယ်
flutter emulators --launch Medium_Phone_API_37.0    # emulator ဖွင့်ပြီး boot ပြီးအောင် စောင့်ပါ

$ANDROID_HOME/platform-tools/adb devices            # emulator-5554  device ပြရမယ်
```

Boot ပြီးမပြီး စစ်ချင်ရင်:

```bash
$ANDROID_HOME/platform-tools/adb wait-for-device
$ANDROID_HOME/platform-tools/adb shell getprop sys.boot_completed   # 1 = boot ပြီး
```

AVD အသစ်လိုချင်ရင်တော့ `flutter emulators --create --name MyPhone` (သို့မဟုတ် Android Studio → Device Manager) နဲ့ ဖန်တီးနိုင်ပါတယ်။

### App ကို emulator ပေါ်မှာ run လုပ်ပါ

```bash
cd /home/mr_robot/Desktop/employee_tasks_dashboard/mobile_app
flutter run -d emulator-5554 --debug
```

Device တစ်ခုတည်းပဲ ချိတ်ထားရင် `flutter run` လို့ပဲ ရိုက်လို့ရပါတယ်။ `flutter run` ဖွင့်ပြီးနောက် terminal ထဲမှာ `r` = hot reload, `R` = hot restart, `q` = quit ဖြစ်ပါတယ်။

Android Studio သုံးနေရင်လည်း အပေါ်က device dropdown ထဲက `Medium Phone API 37.0` ကိုရွေးပြီး ▶ Run နှိပ်လို့ရပါတယ်။

ပထမဆုံး ဖွင့်တဲ့အခါ Settings မဖြည့်ရသေးရင် **"Set the server URL and mobile API token in Settings first."** ဆိုတဲ့ စာပြလိမ့်မယ် — အဲဒါ ပုံမှန်ပါပဲ။ နောက်တစ်ဆင့်အတိုင်း ⚙️ ကနေ URL နဲ့ token ထည့်ပြီး sync လုပ်ပါ။

### Server က ဒီစက်ထဲမှာပဲ ရှိနေရင် (အရေးကြီး)

Emulator ရဲ့ `localhost` က သူ့ကိုယ်သူ ဖြစ်နေတယ် — `http://localhost...` မသုံးပါနဲ့။ ဒီ project ရဲ့ default `docker-compose.yml` က host ပေါ်မှာ port 80/443 ပဲ ဖွင့်ပြီး 80 က https ကို redirect လုပ်တယ်၊ cert လည်း `.env` ထဲက `${DOMAIN}` အတွက်ဖြစ်တယ်။ ဒါကြောင့် emulator ထဲမှာ IP (`10.0.2.2`) နဲ့ စမ်းတာထက် **တကယ့် domain URL ကိုပဲ ထည့်ပါ** — ဥပမာ `https://dashboard.example.com`။

တကယ်လို့ ဒီစက်ထဲက Flask ကို port 8000 တိုက်ရိုက် (nginx မပါဘဲ) ဖွင့်စမ်းနေရင်တော့ `http://10.0.2.2:8000` သုံးလို့ရပါတယ်။

### ဒီ project မှာ ရလဒ်

```
flutter emulators --launch Medium_Phone_API_37.0 → emulator-5554 boot ပြီး (Android 17, x86_64)
flutter run -d emulator-5554 --debug             → Launching lib/main.dart ... Syncing files to device ... 103ms
မျက်နှာပြင်                                      → "Employee Tasks / Daily log" ပြ၊ ⚙️ မြင်ရ၊ error မရှိ
```

---

## ၄။ Server ဘက်မှာ လုပ်ရမယ့်အရာ

`.env` ထဲမှာ mobile အတွက် read-only token ထည့်ပါ (အနည်းဆုံး စာလုံး ၃၂ လုံး):

```bash
openssl rand -hex 32      # token အသစ်ထုတ်ဖို့
```

```dotenv
MOBILE_API_TOKEN=ဒီနေရာမှာ_token_ထည့်ပါ
MOBILE_ADMIN_TOKEN=ဒီနေရာမှာ_admin_token_ထည့်ပါ
```

Admin token က သီးခြားတစ်ခုဖြစ်ရမယ် (`openssl rand -hex 32` နဲ့ ထပ်ထုတ်ပါ)။ ဖုန်းကနေ user/group/carry settings ပြောင်းဖို့ ဒီ token လိုအပ်တယ်။

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
| `GET /api/mobile/settings` | user/group/carry settings + counts (read token) |
| `PUT /api/mobile/settings` | settings သိမ်း (admin token) |

`X-Mobile-Token` header မပါရင် **401** ပြန်တယ်။ Token မထည့်ထားရင် endpoint တွေ ပိတ်ထားတာနဲ့ အတူတူပါပဲ။

---

## ၅။ App ထဲမှာ Settings ဖြည့်ပါ

App ကို ဖွင့်ပြီး ညာဘက်အပေါ်က ⚙️ (Settings) ကို နှိပ်ပါ:

1. **Dashboard server URL** — ဥပမာ `https://dashboard.example.com` (nginx က port 443 မှာ ရှိတယ်)
2. **Mobile API token** — အပေါ်က `MOBILE_API_TOKEN` နဲ့ တူတူ
3. **Sync from server** ကို နှိပ်ပါ (app ဖွင့်တိုင်း အလိုအလျောက်လည်း sync လုပ်တယ်)

### Telegram access & carry settings (admin)

⚙️ Settings → **Telegram access & carry settings** ထဲမှာ —

- **Mobile admin token** ထည့်ပြီး **Load** နှိပ်ပါ။ ပထမအကြိမ်မှာ `.env` ထဲက allowlist တွေကနေ user/group စာရင်း ဖန်တီးပေးပါတယ်။
- User တစ်ယောက်ချင်းစီမှာ **ID / Username / Display name** နဲ့ role checkbox ၄ ခု ရှိပါတယ်:
  - `Employee` → `/task_lists`, `/report` သုံးခွင့် (`TELEGRAM_STANDARD_USER_IDS`)
  - `Manager` → task assign / end (`TELEGRAM_TASK_ASSIGN_USER_IDS`)
  - `Private chat may use commands` → (`TELEGRAM_ALLOWED_CHAT_IDS`)
  - `Receives report notifications` → (`TELEGRAM_REPORT_RECEIVED_CHAT_IDS`)
- **User ကို `/start` မနှိပ်ခင်ကြိုထည့်လို့ရပါတယ်** — username/name ကို အခုပဲ မှတ်ထားပြီးနောက်မှ bot က လက်ခံပါလိမ့်မယ်။
- Group ထပ်ထည့်လို့ရတယ် (negative chat ID)။ ရှိပြီးသား group လည်း ဒီထဲမှာ ပြောင်းလို့ရတယ်။
- **Carry notification days** — carry က နေ့တိုင်း လုပ်နေတုန်းပဲ၊ checkbox ချထားတဲ့ weekday တွေမှာပဲ Telegram noti ပို့တယ်။ မချထားတဲ့နေ့က carry လုပ်ပေမယ့် noti မရောက်ဘူး။
- **Save to server** နှိပ်ပြီး ၁၀ စက္ကန့်အတွင်း bot က အလိုအလျောက် ပြန်ဖတ်သွားပါတယ် (restart မလို)။

Settings ဖိုင်က `json_data_records/mobile_settings.json` (Docker မှာ bind-mounted) ထဲ သိမ်းတယ် — `.env` ကို မထိပါဘူး။ ဖိုင်မရှိသေးရင် `.env` allowlist တွေကိုပဲ သုံးထားတယ်။

---

## ၆။ APK ထုတ်နည်း (ဘယ်ကစပြီး ဘာရိုက်ရမလဲ)

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

## ၇။ ဒေတာ ဘယ်လိုရောက်လဲ

```
Server json_data_records ──(GET /api/mobile/data/<date>)──▶ App ──▶ ဖုန်းထဲ cache
```

- App ဖွင့်တဲ့အခါ / ရက်ပြောင်းတဲ့အခါ / sync button / pull-to-refresh တို့မှာ server ကို တောင်းတယ်။
- ပြန်ရတဲ့ JSON ကို `SharedPreferences` ထဲ သိမ်းပြီး UI က အဲဒီ cache ကပဲ ဖတ်တယ် — network မရှိရင်လည်း အရင်ဒေတာ ပြနေမယ်။
- Card တွေက default အနေနဲ့ ကျုံ့ထားပါတယ် — date row ရဲ့ ညာဘက်ဆုံး ▾ **Expand details** နှိပ်မှ description / Engineer Report / Assigned by အသေးစိတ်တွေ ပြတယ်။ ဒါကြောင့် data နည်းများအလိုက် card အရွယ်အစား ရုတ်တရက် မပြောင်းတော့ဘူး။
- Engineer နာမည်ပြတဲ့နေရာမှာ `@username` ကို မပြဘဲ alias/နာမည်ပဲ ပြတယ်။ နာမည်ကို နှိပ်တာ (သို့) ဖိထားတာနဲ့ `@username` ပြလာပြီး Telegram profile ကို ဖွင့်ပေးတယ် (WebUI မှာလည်း အတူတူပါပဲ)။
- **Server က ကိုယ်တိုင် push လုပ်တာ မရှိတော့ပါဘူး** — အသစ်ရေးထားတဲ့ task က app ဖွင့်/refresh လုပ်မှ ရောက်မယ်။

---

## ၈။ လုံခြုံရေး

- `MOBILE_API_TOKEN` ကိုလည်း လျှို့ဝှက်ထားပါ — ဒါက နေ့စဉ် အချက်အလက်အားလုံးကို ဖတ်ခွင့်ပေးတယ်။

---

## ၉။ အခက်အခဲ တွေ့ရင်

| လက္ခဏာ | ဖြေရှင်းနည်း |
| --- | --- |
| `401` ပြတယ် | App Settings ထဲက token နဲ့ server `.env` ထဲက `MOBILE_API_TOKEN` တူမတူ စစ်ပါ |
| Emulator မတွေ့ / `flutter run` က device မရှိဘူး | `flutter emulators` နဲ့ AVD ရှိမရှိ စစ်ပါ၊ `flutter emulators --launch <id>` နဲ့ ဖွင့်ပါ၊ `adb devices` မှာ `emulator-5554` ပြရမယ် |
| Emulator boot မဖြစ်ဘူး | `/dev/kvm` ရှိမရှိနဲ့ `flutter doctor -v` စစ်ပါ။ Boot နှေးရင် `adb wait-for-device` ပြီး `getprop sys.boot_completed` က `1` ဖြစ်အောင် စောင့်ပါ |
| Emulator ထဲကနေ server နဲ့ မဆက်ရဘူး | `localhost` မသုံးပါနဲ့။ Default setup မှာ domain URL (`https://<DOMAIN>`) ကိုပဲ သုံးပါ။ Flask ကို 8000 တိုက်ရိုက်ဖွင့်ထားရင်တော့ `http://10.0.2.2:8000` (အပေါ် အခန်း ၃ ကြည့်ပါ) |
| `flutter doctor` မှာ SDK မတွေ့ | `export ANDROID_HOME=$HOME/Android/Sdk` ထားပြီး ပြန်စစ်ပါ |
| Gradle က NDK/platform ပြန်ဆွဲနေတယ် | `android/gradle.properties` ထဲက `android.builder.sdkDownload=false` ကို ဖြေထားမိမိ စစ်ပါ |
| ထူးဆန်းတဲ့ build error | `flutter clean && flutter pub get && flutter build apk --debug` ပြန်လုပ်ပါ |
| 404 | Server URL မှန်မမှန်၊ nginx က 443 မှာ အလုပ်လုပ်နေလား စစ်ပါ |

---

## ၁၀။ အတည်ပြုချက် (ဒီ project မှာ တကယ်လုပ်ခဲ့တာ)

```
flutter analyze                            → No issues found
flutter test                               → 21 tests passed (SSE push test ဖယ်ရှိ၊ scheduled-fetch test ထပ်ထည့်)
flutter build apk                          → BUILD_EXIT=0, app-debug.apk ထွက်ပြီး
flutter emulators --launch ...             → emulator-5554 boot (Android 17, x86_64)
flutter run -d emulator-5554 --debug       → app ဖွင့်၊ "Daily log" မျက်နှာပြင်ပြ၊ error မရှိ
python unittest                            → 30 ထဲ 29 pass (1 က အရင်ကတည်းက ရှိနေတဲ့ fixture ပြဿနာ)
```

---

## ၁၁။ Cron Job (Android အတွက်ပဲ — WebUI မှာ မပါဘူး)

Home screen ရဲ့ **ဘယ်ဘက်အပေါ်က ☰ menu** ကို နှိပ်ပြီး ဘယ်ဘက်က drawer ထဲက **Cron Jobs** ကို ရွေးပါ။ (Drawer ထဲမှာ Dashboard / Cron Jobs / Settings ရှိပါတယ်)။

1. **What to remind** — notification မှာ ပြမယ့်စာသား
2. ရက်နဲ့ အချိန်ကို ရွေးပါ ( နှစ်ခုလုံး **Myanmar Time (MMT)** အတိုင်း အဓိပ္ပာယ်ဖွင့်တယ်)
3. **Phone number for SMS** ထည့်ပြီး **Linked task card** ကနေ task တစ်ခု ရွေးပါ — job က အဲဒီနံပါတ်ဆီ အဲဒီ task အချက်အလက်ပါ SMS ပို့ပါလိမ့်မယ်။
4. **Repeat** မှာ တစ်ခု ရွေးပါ:

| ရွေးချယ်မှု | အပြုအမူ |
| --- | --- |
| `Once` | ရွေးထားတဲ့ ရက်နဲ့အချိန်မှာ တစ်ကြိမ်ပဲ ရောက်တယ် |
| `Every day` | တစ်ကြိမ်သတ်မှတ်ပြီးရင် **နောက်ရက်တိုင်း** အဲဒီအချိန်မှာ ထပ်ရောက်တယ် |
| `Selected weekdays` | ရွေးထားတဲ့ နေ့တွေ (Mon…Sun) မှာ ထပ်ရောက်တယ် — နေ့တစ်ခုချင်းစီအတွက် notification ID သီးခြား သုံးတယ် |

5. **Set job** ကို နှိပ်ပါ။ **SCHEDULED** စာရင်းထဲက မလိုချင်တာကို ညာဘက်က delete icon နဲ့ ဖျက်လို့ရပါတယ်။

App က notification permission နဲ့ exact-alarm permission ကို ဖွင့်တဲ့အခါ တောင်းပါတယ်။ Job တွေက app ပိတ်ထားရင်တောင် notification အဖြစ် ရောက်ပါတယ် (`flutter_local_notifications` + `timezone` သုံးထားတယ်)။ Reboot ပြီးရင် ပြန်လည်သတ်မှတ်ဖို့ boot receiver တွေ manifest ထဲမှာ ထည့်ထားပါတယ်။

SMS ပို့တဲ့ job တွေကို `workmanager` one-off task အဖြစ် စီစဉ်ထားတယ် (`sms-cron-<id>`) — app ပိတ်ထားရင်တောင် background မှာ SMS ပို့နိုင်ပါတယ်။ ထပ်ခါတလဲလဲ job ဆိုရင် ပို့ပြီးတိုင်း နောက်တစ်ခေါက်ကို ပြန်စီစဉ်တယ်။

> UI ကို **Engineer Tasks** လို့ ပြောင်းထားပါတယ်။ Theme (light/dark) ကို Settings ထဲက **APPEARANCE** မှာ ပြောင်းပါတယ် — title bar ထဲက gear icon ကို ဖယ်ထားပါတယ်။

---

## ၁၂။ Contacts နဲ့ Messages (Android အတွက်ပဲ)

ဘယ်ဘက် drawer ထဲက **Contacts** / **Messages** ကနေ ဖွင့်ပါတယ်။

- **Contacts** — ဖုန်းထဲက contact တွေကို ဖတ်ပြတယ် (`flutter_contacts`), ရှာနိုင်တယ်၊ အသစ်ထည့် / ပြင်ဆင် / ဖျက်လို့ရတယ်။ ပထမဆုံး ဖွင့်တဲ့အခါ read/write permission တောင်းပါတယ်။
- **Messages** — ဖုန်းထဲက SMS တွေကို **မဖတ်ပါဘူး**။ ဒီ app ကနေ နံပါတ်တစ်ခုဆီ SMS ပို့နိုင်ပြီး (`sms_sender` + SEND_SMS permission) **ဒီ app က ပို့ထားတဲ့ message တွေကိုပဲ** စာရင်းပြပါတယ် — ဖုန်းထဲမှာ သိမ်းပါတယ်။

> SMS ပို့တာကို emulator မှာ SIM မရှိလို့ စမ်းလို့ မရပါဘူး — တကယ့် device မှာ စမ်းပါ။ ကုဒ်မှာတော့ fake gateway နဲ့ unit/widget test တွေ ရပါပြီ။

---

---

## ၁၃။ Scheduled fetch (Firebase / SSE မသုံးပဲ)

အခု app က server ဆီကနေ **schedule လုပ်ထားတဲ့ fetch** နဲ့ပဲ အလုပ်လုပ်ပါတယ် — SSE stream နဲ့ FCM နှစ်ခုလုံး ဖယ်ထားပါတယ်။

- `workmanager 0.10.10` နဲ့ Android WorkManager periodic task (`employee-tasks-fetch`) ကို **၁ နာရီတစ်ခေါက်** (network ရှိမှ) စီစဉ်ထားတယ်။
- Background task က `/api/mobile/dates` + `/api/mobile/data/<date>` ကို ခေါ်ပြီး cache ထဲက အရင်ဒေတာနဲ့ `updated_at` ယှဉ်တယ်။ **ပြောင်းမှသာ** local notification ပြတယ် (`shouldNotify()`)။
- App ဖွင့်ထားတဲ့အခါ ရိုးရိုး sync (open / date change / button / pull-to-refresh) ကတော့ အရင်အတိုင်း ရှိနေတယ်။

> WorkManager က app ပိတ်ထားရင်တောင် background မှာ အလုပ်လုပ်ပါတယ် — Firebase credential မလိုပါဘူး။ OEM battery optimizer တွေကတော့ နှောင့်နှေးစေနိုင်ပါတယ်။
