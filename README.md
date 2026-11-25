# Employee Tasks Dashboard

ဝန်ထမ်းအလုပ်များကို Telegram bot ကနေ assign လုပ်၊ နေ့စဉ် report တင်ပြီး Web Dashboard မှာ ရက်အလိုက် ကြည့်နိုင်တဲ့ project ဖြစ်ပါတယ်။ မပြီးသေးတဲ့ task တွေကို မြန်မာအချိန် နေ့ကူးချိန်မှာ နောက်နေ့ဆက်သယ်ပြီး `/end_task` နဲ့ အဆုံးသတ်ထားတဲ့ task တွေကို ဆက်မသယ်တော့ပါ။

## Project အလုပ်လုပ်ပုံ

| အပိုင်း | တာဝန် |
|---|---|
| `web_dashboard/` | HTML/CSS/JavaScript dashboard နဲ့ login စာမျက်နှာ |
| `backend_python/web_app.py` | Flask login၊ session၊ dashboard နဲ့ JSON ဖိုင်များကို serve လုပ်ခြင်း |
| `backend_python/bot.py` | Telegram commands၊ access control၊ task assignment/report၊ နေ့ကူး carry |
| `backend_python/update_tasks.py` | JSON data ကို lock နဲ့ atomic replacement သုံးပြီး ပြင်ခြင်း |
| `backend_python/start.py` | Container တစ်ခုထဲမှာ Gunicorn web server နဲ့ Telegram bot ကို အတူ run ခြင်း |
| `json_data_records/` | `YYYY-MM-DD.json` အဖြစ် နေ့စဉ် task/report သိမ်းခြင်း |
| `nginx_proxy/` | HTTPS၊ HTTP redirect နဲ့ login rate limit |
| `docker-compose.yml` | App/bot နဲ့ Nginx containers ကို ချိတ်ဆက်ခြင်း |
| `automation` | Compose stack ကို down လုပ်ပြီး build/start ပြန်လုပ်ခြင်း |
| `cronjob` | Host ပေါ်က repository changes ကို Git commit/push လုပ်ခြင်း |

Database server သီးခြားမလိုပါ။ Browser က Nginx port 443 ကို ချိတ်ပြီး Nginx က Docker network ထဲရှိ app port 8000 ကို ဆက်ပေးပါတယ်။ Telegram bot က polling သုံးတာမို့ webhook domain သီးခြားမလိုပါ။

## VPS ပေါ်တွင် အဆင့်လိုက်တင်ခြင်း

အောက်က commands တွေက **Ubuntu 24.04 LTS VPS အသစ်** နဲ့ sudo သုံးနိုင်တဲ့ ပုံမှန် user အတွက် ဖြစ်ပါတယ်။ အခြား OS သုံးရင် Docker install အဆင့်ကို အဲဒီ OS အလိုက် ပြောင်းပါ။ ကိုယ့် PC မှာ run ရမယ့် command ကိုသာ သီးခြားဖော်ပြထားပြီး ကျန်တာအားလုံး VPS terminal မှာ run ပါ။

### ၁။ VPS နဲ့ domain ပြင်ဆင်ပါ

လိုအပ်တာတွေက VPS public IP၊ SSH account၊ domain/subdomain၊ Telegram bot token နဲ့ repository access ဖြစ်ပါတယ်။

ကိုယ့် PC terminal ကနေ:

```bash
ssh YOUR_VPS_USER@YOUR_VPS_IP
```

DNS provider မှာ `dashboard.your-domain.com` ရဲ့ A record ကို VPS IPv4 သို့ ညွှန်းပါ။ AAAA record ရှိရင် VPS ရဲ့ တကယ်အသုံးပြုနိုင်တဲ့ IPv6 သို့ ညွှန်းထားရပါမယ်။ VPS provider firewall မှာ ကိုယ်သုံးတဲ့ SSH port နဲ့ TCP 80/443 ကို ခွင့်ပြုပါ။ App port 8000 ကို public မဖွင့်ပါနဲ့။

VPS မှာ စစ်ရန်:

```bash
cat /etc/os-release
uname -m
getent ahosts dashboard.your-domain.com
```

`dashboard.your-domain.com` ကို နောက်အဆင့်အားလုံးမှာ ကိုယ့် domain နဲ့ အစားထိုးပါ။

### ၂။ Docker Compose နဲ့ အခြေခံ tools တင်ပါ

Docker ရှိပြီးသားဆို `sudo docker version` နဲ့ `sudo docker compose version` ကို အရင်စစ်ပါ။ မရှိသေးတဲ့ Ubuntu VPS မှာ [Docker တရားဝင် APT နည်းလမ်း](https://docs.docker.com/engine/install/ubuntu/) အတိုင်း:

```bash
sudo apt update
sudo apt install -y ca-certificates curl git python3 certbot
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
printf '%s\n' \
  'Types: deb' \
  'URIs: https://download.docker.com/linux/ubuntu' \
  "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}" \
  'Components: stable' \
  "Architectures: $(dpkg --print-architecture)" \
  'Signed-By: /etc/apt/keyrings/docker.asc' \
  | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker compose version
```

ဒီလမ်းညွှန်မှာ Docker commands ကို `sudo` နဲ့ ခေါ်ထားလို့ docker group ထပ်ထည့်ရန် မလိုပါ။

### ၃။ Project ကို clone လုပ်ပါ

```bash
mkdir -p "$HOME/apps"
cd "$HOME/apps"
git clone https://github.com/Open-Source-Robotics-For-Myanmar/employee_tasks_dashboard.git
cd employee_tasks_dashboard
```

Private repository ဖြစ်ရင် သင့် GitHub access ကို အရင်ပြင်ဆင်ပါ။ နောက်ပိုင်း Git push backup သုံးမယ်ဆို VPS user ရဲ့ SSH key နဲ့ repository write access လည်း လိုပါတယ်။

နောက် commands တွေကို ဒီ repository root ကနေ run ပါ။ Terminal အသစ်ဖွင့်တိုင်း:

```bash
cd "$HOME/apps/employee_tasks_dashboard"
```

### ၄။ Data folder ကို bot ရေးလို့ရအောင် ပြင်ပါ

**လက်ရှိ Compose မှာ `./json_data_records:/data:ro` ဖြစ်နေပါတယ်။** App နဲ့ bot က container တစ်ခုတည်းကို သုံးတာမို့ ဒီ mount အတိုင်းဆို task/report ရေးရာမှာ `Read-only file system` error ဖြစ်ပါမယ်။ Deploy မလုပ်ခင် `docker-compose.yml` ရဲ့ `web-dashboard.volumes` ကို ဒီလိုပြောင်းပါ:

```yaml
volumes:
  - ./json_data_records:/data
```

တခြား Nginx config/certificate mounts တွေက `:ro` အတိုင်းထားပါ။ ဒီအဆင့်က **README ထဲက လုပ်ဆောင်ရန်ညွှန်ကြားချက်** ဖြစ်ပြီး Compose ဖိုင်ကို အလိုအလျောက်ပြင်ပေးတာ မဟုတ်ပါ။

```bash
mkdir -p json_data_records
nano docker-compose.yml
```

Repository ထဲက sample JSON ဖိုင်တွေကြောင့် preview tasks တွေ မြင်ရနိုင်ပါတယ်။ Sample data နဲ့ real assignment ကို ရောမရေးနိုင်အောင် CLI မှာ ကာကွယ်ထားပြီး carry လုပ်ရာမှာ sample day ကို အစားထိုးနိုင်ပါတယ်။ Real data ရှိတဲ့ JSON ကို sample လို့ယူဆပြီး မဖျက်ပါနဲ့။

### ၅။ Telegram bot နဲ့ environment ပြင်ပါ

Telegram မှာ **@BotFather** ကိုဖွင့်ပြီး `/newbot` နဲ့ bot ဆောက်ပါ။ ရလာတဲ့ token ကို နောက်က `.env` ထဲ ထည့်ပါ။

```bash
# .env မရှိသေးရင်သာ template မှ ကူးပါ
if [ ! -f .env ]; then cp .env.example .env; fi
chmod 600 .env
```

Dashboard password hash ထုတ်ရန်:

```bash
sudo docker run --rm -it python:3.12-slim sh -c 'pip install --quiet werkzeug && python -c "from werkzeug.security import generate_password_hash; import getpass; print(generate_password_hash(getpass.getpass()))"'
```

Password ကို prompt မှာရိုက်ပါ။ Output hash ကို copy လုပ်ပါ။ Session secret သီးခြားထုတ်ရန်:

```bash
python3 -c 'import secrets; print(secrets.token_hex(32))'
nano .env
```

`.env` ကို ဒီပုံစံ ဖြည့်ပါ။ နမူနာတန်ဖိုးတွေကို တကယ့်တန်ဖိုးတွေနဲ့ အစားထိုးရပါမယ်:

```dotenv
DOMAIN=dashboard.your-domain.com
TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN
TELEGRAM_TASK_ASSIGN_USER_IDS=
TELEGRAM_STANDARD_USER_IDS=
TELEGRAM_ALLOWED_CHAT_IDS=
WEB_DASHBOARD_USERNAME=YOUR_LOGIN_USERNAME
WEB_DASHBOARD_PASSWORD_HASH='PASTE_GENERATED_HASH_HERE'
WEB_DASHBOARD_SECRET_KEY='PASTE_GENERATED_SECRET_HERE'
```

Hash မှာ `$` ပါလို့ **single quotes** နဲ့ပိတ်ပါ။ Raw password ကို `.env` ထဲ မထည့်ပါနဲ့။ `.env` က shell script မဟုတ်တာကြောင့် `source .env` လုပ်ရန်မလိုပါ။ Docker Compose က ဖတ်ပေးပါတယ်။

Telegram IDs မသိသေးရင် allowlists သုံးခုကို ယာယီအလွတ်ထားပြီး အဆင့် ၇ အထိ ဆက်လုပ်နိုင်ပါတယ်။ Bot run ပြီးမှ `/whoami` နဲ့ ID ရယူပါ။ ID မဖြည့်သေးခင် task commands တွေကို ခွင့်မပြုပါ။

### ၆။ HTTPS certificate ရယူပါ

DNS က VPS ကို ညွှန်းပြီး port 80 လွတ်နေမှ standalone certificate ယူနိုင်ပါတယ်။ [Certbot standalone documentation](https://eff-certbot.readthedocs.io/en/stable/using.html#standalone)

```bash
sudo ss -ltnp | grep -E ':(80|443)[[:space:]]' || true
sudo certbot certonly --standalone --cert-name dashboard.your-domain.com -d dashboard.your-domain.com
sudo certbot certificates
```

Email နဲ့ terms prompt ကို ဖြည့်ပါ။ Host ပေါ်မှာ Nginx/Apache သို့မဟုတ် တခြား website က port 80/443 သုံးနေရင် အဲဒီ deployment နဲ့ port ခွဲစီစဉ်ပြီးမှ ဆက်ပါ။

`.env` ရဲ့ `DOMAIN` နဲ့ `/etc/letsencrypt/live/DOMAIN/` certificate directory နာမည် ကိုက်ရပါမယ်။ Compose က `/etc/letsencrypt` ကို Nginx ထဲ read-only mount လုပ်ပါတယ်။

### ၇။ Containers စတင်ပြီး စစ်ပါ

```bash
sudo docker compose config --quiet
sudo docker compose up -d --build
sudo docker compose ps
sudo docker compose logs --tail=100 web-dashboard nginx_proxy
```

`web-dashboard` က healthy ဖြစ်ပြီး `nginx_proxy` က running ဖြစ်ရပါမယ်။ Browser မှာ `https://dashboard.your-domain.com/` ဖွင့်ပြီး အဆင့် ၅ မှာ သတ်မှတ်တဲ့ username နဲ့ မူရင်း password ကို သုံးပါ။ Hash ကို password အဖြစ် မရိုက်ပါနဲ့။

```bash
curl -I https://dashboard.your-domain.com/
curl -fsS https://dashboard.your-domain.com/health
```

Login မဝင်သေးရင် `/` က login သို့ redirect ပြန်ပြီး `/health` က `ok` ပြရပါမယ်။ Health check က web server ကိုသာ စစ်တာဖြစ်လို့ bot report ရေးနိုင်မှုကို အဆင့် ၉ မှာ သီးခြားစမ်းပါ။

`automation` သုံးချင်ရင် `sudo bash ./automation` နဲ့ခေါ်နိုင်ပါတယ်။ ဒီ script က အရင် `docker compose down` လုပ်တာမို့ ခဏ downtime ရှိပါတယ်။ ပုံမှန် update အတွက် `sudo docker compose up -d --build` နဲ့လည်း ရပါတယ်။

### ၈။ Telegram အသုံးပြုသူခွင့်ပြုချက် ဖြည့်ပါ

Bot run နေချိန်မှာ admin နဲ့ ဝန်ထမ်းတစ်ယောက်ချင်းက bot ကို private message ပို့ပြီး `/whoami` ခေါ်ပါ။ Group မှာသုံးမယ်ဆို group ထဲမှာလည်း `/whoami` ခေါ်ပြီး chat ID ရယူပါ။

| Variable | ထည့်ရမည့်တန်ဖိုး |
|---|---|
| `TELEGRAM_TASK_ASSIGN_USER_IDS` | Task assign လုပ်ခွင့်ရှိတဲ့ admin user IDs |
| `TELEGRAM_STANDARD_USER_IDS` | ဝန်ထမ်း user IDs; assignment ရွေးချယ်စာရင်းက ဒီ list ကို သုံးပါတယ် |
| `TELEGRAM_ALLOWED_CHAT_IDS` | Commands သုံးမယ့် private/group chat IDs |

IDs အများအပြားကို comma ခြားပါ။ Group chat ID က negative ဖြစ်နိုင်ပါတယ်။ User ID နဲ့ လက်ရှိ chat ID **နှစ်ခုလုံး** allowlist ထဲရှိမှ command သုံးနိုင်ပါတယ်။

```bash
nano .env
sudo docker compose up -d --force-recreate web-dashboard
```

`.env` ပြောင်းပြီး `docker compose restart` သာလုပ်ရင် environment အသစ် မဝင်နိုင်လို့ container ကို recreate လုပ်ပါ။ ဝန်ထမ်းတွေမှာ Telegram username ရှိရပြီး bot ကို `/start` ပို့ထားရပါတယ်။ ဒါမှ employee list ထဲ ပေါ်ပြီး bot က private task notification ပို့နိုင်ပါတယ်။

BotFather မှာ `/setcommands` ရွေးပြီး အောက်ပါစာရင်းကို ထည့်နိုင်ပါတယ်:

```text
start - Start the bot
whoami - Show user and chat IDs
task_assign - Assign a task
task_lists - View tasks and reports
report - Report task progress
carry - Carry an unfinished task
end_task - Complete a task
cancel - Cancel current workflow
```

Menu ထည့်ခြင်းက permission ပေးခြင်း မဟုတ်ပါ။ ခွင့်ပြုချက်ကို bot ရဲ့ allowlists က စစ်ပါတယ်။

### ၉။ တကယ်အလုပ်လုပ်ကြောင်း စမ်းပါ

1. Admin က `/task_assign` ခေါ်၊ task name ဖြည့်၊ employee ရွေး၊ description ဖြည့်ပါ။ ID ကို bot က ထုတ်ပေးပါတယ်။
2. ရွေးထားတဲ့ employee ဆီ task notification ရောက်မရောက် စစ်ပါ။ Delivery fail ဖြစ်ပေမဲ့ task က သိမ်းပြီးသားဖြစ်နိုင်ပါတယ်။
3. Employee က `/task_lists` သို့မဟုတ် `/report` နဲ့ task ရွေးပြီး report ပို့ပါ။ Report တစ်ခုချင်းစီမှာ မြန်မာအချိန် date/time သိမ်းပါတယ်။
4. Dashboard မှာ သက်ဆိုင်ရာရက်ကိုရွေးပြီး task/report ကို စစ်ပါ။
5. Employee က မိမိ task ကို `/end_task` နဲ့ အဆုံးသတ်ပါ။ Admin က task အားလုံးကို အဆုံးသတ်နိုင်ပါတယ်။
6. `/cancel` က လက်ရှိအပြန်အလှန်ဖြည့်နေတဲ့ workflow ကို ရပ်ပေးပါတယ်။

မပြီးသေးတဲ့ task တွေကို bot startup နဲ့ မြန်မာအချိန် နေ့ကူးချိန်တွေမှာ carry စစ်ပါတယ်။ နေ့သစ်ထဲက carried task ရဲ့ report history က အသစ်စပါတယ်။ Manual carry လိုရင် admin က:

```text
/carry
ID: TASK_ID
From date: 2026-11-25
```

VPS မှာ data နဲ့ logs ကို စစ်ရန်:

```bash
ls -lh json_data_records/
sudo docker compose logs --tail=100 web-dashboard
```

## နေ့စဉ် Git backup

Git backup က host ပေါ်မှာလုပ်ပြီး Telegram bot က commit/push မလုပ်ပါ။ ဝန်ထမ်းအချက်အလက်တွေကို public repository သို့ မတင်လိုပါက private repository သုံးပါ။

```bash
git config user.name 'YOUR_NAME'
git config user.email 'YOUR_EMAIL'
git remote set-url origin git@github.com:Open-Source-Robotics-For-Myanmar/employee_tasks_dashboard.git
```

VPS user ရဲ့ SSH public key ကို GitHub account သို့မဟုတ် write-enabled deploy key အဖြစ် ထည့်ပါ။ Cron က password မမေးနိုင်တာကြောင့် unattended Git access အလုပ်လုပ်ရပါမယ်။ Private key နဲ့ `.env` ကို repository ထဲ မထည့်ပါနဲ့။

**လက်ရှိ `cronjob` မှာ `git add .` သုံးပြီး changes မရှိရင် commit error ကြောင့် push မရောက်ပါ။** Daily data backup အတွက် cron မချိတ်ခင် အဲဒီဖိုင်ကို အောက်ပါအတိုင်း ပြင်နိုင်ပါတယ်:

```sh
#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$repo_dir"
git add -- json_data_records/
if ! git diff --cached --quiet; then
    git commit -m "Daily task data update"
fi
git push
```

ဒီ command က staged ဖြစ်ပြီးသားအခြား changes တွေလည်း commit ထဲပါနိုင်လို့ backup repo working tree မှာ development changes တွေ stage မထားပါနဲ့။ Bot container က root အဖြစ်ရေးထားတဲ့ဖိုင်တွေကို host user က မဖတ်နိုင်ရင် ownership/permissions ကိုစစ်ပါ။

```bash
/bin/sh ./cronjob
mkdir -p "$HOME/.local/state/employee_tasks_dashboard"
date '+%F %T %Z %z'
crontab -e
```

အောက်က schedule နှစ်မျိုးထဲက VPS timezone နဲ့ကိုက်တဲ့ **တစ်ကြောင်းတည်း** ထည့်ပါ။ `/home/YOUR_USER/` ကို တကယ့် absolute path နဲ့ပြောင်းပါ။ Logs ကို repo အပြင်မှာထားပါတယ်။

```cron
# VPS timezone UTC ဖြစ်လျှင် 12:30 UTC = 19:00 Myanmar
30 12 * * * /bin/sh /home/YOUR_USER/apps/employee_tasks_dashboard/cronjob >> /home/YOUR_USER/.local/state/employee_tasks_dashboard/backup.log 2>&1
```

```cron
# VPS timezone Asia/Yangon ဖြစ်လျှင်
0 19 * * * /bin/sh /home/YOUR_USER/apps/employee_tasks_dashboard/cronjob >> /home/YOUR_USER/.local/state/employee_tasks_dashboard/backup.log 2>&1
```

## HTTPS certificate သက်တမ်းတိုးခြင်း

Standalone renewal အတွက် port 80 လွတ်ရပါမယ်။ ကိုယ့် deployment ရဲ့ certificate ကိုပဲ ရွေးပြီး pre/post hooks နဲ့ proxy ရပ်/ပြန်စပါ။ Certbot renewal timer ကလည်း hooks ကိုသုံးနိုင်အောင် တပ်ဆင်ထားရပါမယ်။ [Certbot renewal documentation](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates)

```bash
cd "$HOME/apps/employee_tasks_dashboard"
PROJECT_DIR="$PWD"
sudo certbot renew --cert-name dashboard.your-domain.com --dry-run \
  --pre-hook "docker compose --project-directory '$PROJECT_DIR' stop nginx_proxy" \
  --post-hook "docker compose --project-directory '$PROJECT_DIR' start nginx_proxy"
```

Dry run အောင်မြင်ရင် `--dry-run` ဖြုတ်ပြီး run ပါ။ Hook options သိမ်းထားမှုကို `/etc/letsencrypt/renewal/` ထဲက သက်ဆိုင်ရာ config မှာ စစ်ပါ။ `sudo systemctl list-timers --all | grep certbot` နဲ့ renewal timer ရှိမရှိ စစ်ပါ။ Proxy ပြန်စတဲ့အခါ certificate အသစ်ကို ဖတ်ပါတယ်။ Renewal လုပ်ချိန် web access ခဏပြတ်နိုင်ပါတယ်။

## Update နှင့် troubleshooting

Project root မှာ `git status` နဲ့ local data/config changes ကို အရင်စစ်ပြီး လိုအပ်တဲ့ commit/backup လုပ်ပါ။ ပြီးမှ:

```bash
git pull --ff-only
sudo docker compose up -d --build
sudo docker compose ps
sudo docker compose logs --tail=100 web-dashboard nginx_proxy
```

| လက္ခဏာ | စစ်ရမည့်အချက် |
|---|---|
| `Read-only file system` | အဆင့် ၄ ရဲ့ data mount ကိုပြင်ပြီး container recreate လုပ်ပါ |
| App restart ထပ်ခါဖြစ် | Bot token၊ login env variables နဲ့ child process logs စစ်ပါ; bot သို့မဟုတ် Gunicorn တစ်ခုရပ်ရင် supervisor က container ကိုရပ်ပါတယ် |
| Nginx certificate မတွေ့ | `DOMAIN` နဲ့ certificate directory ကိုက်မကိုက် စစ်ပါ |
| Telegram permission denied | User ID နဲ့ chat ID နှစ်ခုလုံး allowlists ထဲ ပါရပါမယ် |
| Employee ရွေးရန်မပေါ် | Standard user ID၊ Telegram username နဲ့ bot `/start` စစ်ပါ |
| Telegram polling conflict | တူညီတဲ့ token နဲ့ bot instance နှစ်ခု run နေမနေ စစ်ပါ |
| Login HTTP ပေါ်မှာ မတည်မြဲ | Secure cookie ဖြစ်လို့ HTTPS domain နဲ့ ဝင်ပါ |
| Git push fail | Host Git SSH access၊ branch နဲ့ remote changes စစ်ပါ |
| `429` login error | Nginx login rate limit ဖြစ်နိုင်လို့ ခဏစောင့်ပါ |

## Local Python development နှင့် tests

Docker deployment မှာ container က `requirements.txt` ကို install လုပ်ပြီးသားမို့ host `.venv` မလိုပါ။ Local development အတွက်:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python backend_python/update_tasks.py --help
```

လက်ရှိ tests က dashboard authentication ကိုစစ်တဲ့ ၅ ခု ဖြစ်ပါတယ်။ Bot workflow၊ Docker deployment နဲ့ certificate renewal ကို ဒီ tests က မစစ်ပါ။

CLI နဲ့ task ပြင်နည်း၊ report timestamp နဲ့ manual carry အသေးစိတ်ကို [backend_python/README.md](backend_python/README.md) မှာ ဖတ်နိုင်ပါတယ်။ CLI က local JSON ကိုသာပြင်ပြီး Telegram message မပို့ပါ။

References:

- [docker-compose.yml](docker-compose.yml)
- [Dockerfile](Dockerfile)
- [.env.example](.env.example)
- [backend_python/start.py](backend_python/start.py)
- [backend_python/bot.py](backend_python/bot.py)
- [backend_python/web_app.py](backend_python/web_app.py)
- [backend_python/update_tasks.py](backend_python/update_tasks.py)
- [nginx_proxy/default.conf.template](nginx_proxy/default.conf.template)
- [automation](automation)
- [cronjob](cronjob)
