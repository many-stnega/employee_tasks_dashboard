# Employee Tasks Dashboard

The dashboard serves daily task logs from `json_data_records/YYYY-MM-DD.json`.

## Run with Docker

Run these commands from the repository root:

```sh
cp .env.example .env
# Add your Telegram bot token to .env before starting the container.
docker build -t employee-tasks-dashboard .
docker run --detach \
  --name employee-tasks-dashboard \
  --publish 8080:80 \
  --env TZ=Asia/Yangon \
  --env-file "$PWD/.env" \
  --volume "$PWD/json_data_records:/usr/share/nginx/html/data" \
  employee-tasks-dashboard
```

The container uses Myanmar Time (`Asia/Yangon`), and the host
`json_data_records/` directory is mounted into the website. Nginx and the
Python Telegram bot run together in this same container. Open
<http://localhost:8080>. The `automation` script builds and starts it from the
repository root:

```sh
bash ./automation
```

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
| `/task_lists` | Show today's tasks, assignments, and employee reports. | Both user lists, in allowed chats |
| `/report` | Choose today's task and record an employee report. | Both user lists, in allowed chats |
| `/carry` | Carry an unfinished task from an earlier date into today's log. | Users in `TELEGRAM_TASK_ASSIGN_USER_IDS`, in allowed chats |

To show these in Telegram's command menu, open **@BotFather**, send `/setcommands`,
select your bot, then paste:

```text
start - Start the bot and show the caller's access level.
whoami - Show the caller's Telegram user ID and chat ID.
task_assign - Start the guided task assignment.
task_lists - Show today's tasks, assignments, and employee reports.
report - Choose a task and record an employee report.
carry - Carry an unfinished task from an earlier date into today's log.
cancel - Cancel the current task assignment or report.
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

Both user lists can use `/task_lists` in an allowed chat. Long task lists are
sent as multiple messages.

Report progress on a task in today's log:

```text
/report
```

The bot shows today's tasks as buttons. Tap a task to select it, then send the
report text; it can span multiple lines. Each new report is appended after the
previous report for that task. Send `/cancel` to stop without saving. Both user
lists can use `/report` in an allowed chat.

Carry an unfinished task from an earlier date into today's log:

```text
/carry
ID: task-001
From date: 2026-11-25
```

Only the task-assign user list can run `/carry` in an allowed chat. The source
date must be earlier than today, and the task must exist on that date. The new
entry starts without its previous employee report.
