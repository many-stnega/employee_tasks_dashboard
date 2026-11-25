# Employee Tasks Dashboard

The dashboard serves daily task logs from `json_data_records/YYYY-MM-DD.json`.

## Run with Docker

The VPS deployment runs the dashboard application and Nginx reverse proxy in
separate containers. Only Nginx publishes ports; the dashboard, including its
daily JSON files, is not directly reachable from outside the Docker network.
The dashboard login uses a signed session cookie and protects both pages and
data.

On the VPS, point a DNS name to the server and allow inbound TCP ports 80 and
443. Install Docker Compose and Certbot, then obtain a certificate for that
name while port 80 is not occupied:

```sh
cp .env.example .env
sudo certbot certonly --standalone -d dashboard.example.com
```

Set `DOMAIN` in `.env` to the DNS name used for the certificate. Add the
Telegram bot token and access-control IDs as described below. Generate a
dashboard username, password hash, and independent session secret; the raw
password is not stored in `.env`:

```sh
docker run --rm -it python:3.12-slim sh -c 'pip install --quiet werkzeug && python -c "from werkzeug.security import generate_password_hash; import getpass; print(generate_password_hash(getpass.getpass()))"'
python3 -c 'import secrets; print(secrets.token_hex(32))'
```

The hash command prompts for the password without echoing it. Put the generated
hash and secret into `.env` as single-quoted values (Werkzeug hashes contain
`$` characters), choose a unique username and a strong password (at least 12
characters), and keep `.env` private and never commit it. Then start the stack:

```sh
docker compose up -d --build
```

Open `https://your-domain/`. `nginx_proxy` redirects HTTP to HTTPS, limits
repeated login attempts, and forwards requests only to the internal dashboard
container. The dashboard session cookie is Secure, HttpOnly, SameSite=Strict,
and expires after eight hours. All dashboard files and JSON data require a
valid login. For certificate renewal, stop the proxy before running
`sudo certbot renew`, then start it again; reload the proxy after a renewed
certificate is installed:

```sh
docker compose stop nginx_proxy
sudo certbot renew
docker compose start nginx_proxy
docker compose exec nginx_proxy nginx -s reload
```

The `automation` script builds and starts the full Compose stack from the
repository root. The host `json_data_records/` directory is mounted read-only
inside the dashboard container. Do not publish port 8000 or run the dashboard
container with a separate `docker run` command, as that would bypass the
reverse proxy.

## Commit and push data daily

No backup container or file-copy script is needed: Git stores the
`json_data_records/` files in the repository. The `cronjob` script runs
`git add .`, `git commit`, and `git push` from the repository root. It runs on
the host, where the repository's Git credentials are available.

Open the host's crontab with `crontab -e` and add these lines. Replace the
example paths with the absolute path to this repository:

```cron
CRON_TZ=Asia/Yangon
0 19 * * * /bin/sh /absolute/path/to/employee_tasks_dashboard/cronjob >> /absolute/path/to/employee_tasks_dashboard/data-backup.log 2>&1
```

The cron schedule is 19:00 MMT. `git add .` includes all repository changes,
not just `data/`; keep secrets and unrelated files out of the working tree.
Configure the host Git identity and access to `origin` before enabling the job.

## Python and Telegram development

For local Python development, create a Python virtual environment and install
the Telegram bot dependency from the repository root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Run Python scripts with the environment's interpreter, for example:

```sh
.venv/bin/python backend_python/update_tasks.py --help
```

`.venv/`, Python bytecode, and `.env` files are ignored by Git. Keep the
Telegram bot token in an environment variable or secret; do not commit it.

## Telegram bot and access control

Set `TELEGRAM_BOT_TOKEN` in `.env`; keep this file private and never commit it.
Use two comma-separated Telegram user ID lists in `.env`:

- `TELEGRAM_TASK_ASSIGN_USER_IDS`: users allowed to assign tasks and use
  standard bot commands.
- `TELEGRAM_STANDARD_USER_IDS`: users allowed to use standard commands but not
  assign tasks.

Both lists start empty, so no user is authorized until IDs are configured.
`TELEGRAM_ALLOWED_CHAT_IDS` is an additional chat allowlist; a user's ID and
the current chat ID must both be allowed. `/whoami` reports IDs to help with
configuration. Restart the container after changing `.env`. Group chat IDs
are often negative. Usernames and display names are not authorization
credentials.

`/task_assign` requires the task-assign user list and the allowed chat list.
These are the commands currently implemented in the bot:

| Command | Description | Who can use it |
|---|---|---|
| `/start` | Start the bot and show the caller's access level. | Allowed users in allowed chats |
| `/whoami` | Show the caller's Telegram user ID and chat ID. | Anyone who can message the bot |
| `/task_assign` | Start a guided task assignment, asking one question at a time. | Users in `TELEGRAM_TASK_ASSIGN_USER_IDS`, in allowed chats |
| `/task_lists` | Choose a task by title, view its details, and add a report. | Both user lists, in allowed chats |
| `/report` | Choose today's task and record an employee report. | Both user lists, in allowed chats |
| `/carry` | Carry an unfinished task from an earlier date into today's log. | Users in `TELEGRAM_TASK_ASSIGN_USER_IDS`, in allowed chats |
| `/end_task` | Mark one of your tasks complete so it will not carry forward. | Assigned engineer or task-assign users, in allowed chats |

To show these in Telegram's command menu, open **@BotFather**, send `/setcommands`,
select your bot, then paste:

```text
start - Start the bot and show the caller's access level.
whoami - Show the caller's Telegram user ID and chat ID.
task_assign - Start the guided task assignment.
task_lists - Browse task details and add a report.
report - Choose a task and record an employee report.
carry - Carry an unfinished task from an earlier date into today's log.
end_task - Mark a finished task complete so it will not carry forward.
cancel - Cancel the current bot workflow.
```

The BotFather menu only displays commands; actual access is enforced by this
bot. Send `/task_assign`, enter the task name, choose an employee from the
Telegram username buttons, then enter the description. The bot generates the
task ID automatically. It does not ask for a repository, URL, or sample-task
replacement. Employees must have a Telegram username and have started the bot
to appear as assignable users.

The saved task contains its name, the assigned employee's username, its
description, and any employee report. After saving, the bot sends a formatted
task name and description directly to the selected employee's Telegram user ID;
the internal task ID is not included in that message. Employees must open the
bot and send `/start` before the bot can send them a private message.
If Telegram delivery fails, the task remains saved and the assigning user is
told that the direct message was not delivered.
Send `/cancel` at any time to stop without saving. Only users in
`TELEGRAM_TASK_ASSIGN_USER_IDS` can start or continue this flow.

Show all tasks for today:

```text
/task_lists
```

Both user lists can use `/task_lists` in an allowed chat. It shows task titles
as buttons; choose one to view its complete details and report history. Use the
**Add report** button on the detail card to submit a report directly for that
task. Send `/cancel` to close the task list.

Report progress on a task in today's log:

```text
/report
```

The bot shows today's tasks as buttons. Tap a task to select it, then send the
report text; it can span multiple lines. Each report is saved separately with
its own Myanmar date and time, and the dashboard shows the full report history.
Send `/cancel` to stop without saving. Both user lists can use `/report` in an
allowed chat.
Reports submitted before report history was introduced remain visible as their
existing combined entry; dates for earlier submissions cannot be reconstructed
if they were not stored separately.

Carry an unfinished task from an earlier date into today's log:

```text
/carry
ID: task-001
From date: 2026-11-25
```

Unfinished tasks automatically carry from the previous day in Myanmar time.
Use `/end_task` and select a finished task to mark it complete; completed tasks
will not carry forward. If an unfinished task carries into a day that still has
sample preview data, the sample entries are automatically replaced. Engineers
can end their own tasks, while task-assign users can end any task. `/carry`
remains available for manual carry operations.
