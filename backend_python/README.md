# Agent data commands

Run with Python 3.9+ on Linux. No extra packages or GitHub token are needed to edit local JSON. By default, data is stored in the repository's `json_data_records/` directory; set `TASKS_DATA_DIR` or use `--data-dir` to choose another directory. Examples below assume the repository root.

Global options (`--date`, `--data-dir`) go **before** the subcommand. Without `--date`, the script uses today in Myanmar time (UTC+06:30). `--data-dir` optionally targets another data directory.

## Add or update an assignment

```bash
python3 backend_python/update_tasks.py --date 2026-11-25 assign_task \
  --id task-001 \
  --task 'Implement the login API' \
  --username employee_username \
  --description 'Continue the login API implementation and run integration tests.'
```

An assignment stores the task name, Telegram username, and description; it has
no repository or URL field. The `assigned_to` record contains only the username.

Reuse the same `--id` to update a task, without creating duplicates. Supply all
assignment fields on each `assign_task`; existing employee reports are
preserved. Use a new task ID when assigning different work or changing the
employee, so an old employee's report is not attributed to a new employee.

Sample files are protected against accidental mixing with real work and cannot
be updated by assignment commands.

## Record an employee report

```bash
python3 backend_python/update_tasks.py --date 2026-11-25 report \
  --id task-001 \
  --description 'API implementation is complete. Testing is in progress.' \
  --reported-at '2026-11-25T16:00:00+06:30'
```

The report appears in the right-hand Employee Report column. The assignment
description stays intact, and each new report is saved as a separate entry with
its own date and time. Omit `--reported-at` for the current time. Historical
reports must specify their actual timestamp, falling on the selected date in
Myanmar time.

## Carry an unfinished task to another day

New assignments without `--id` receive IDs such as `20260213-01`, `20260213-02`,
using the assignment date (Myanmar time by default, or `--date`). Each date starts
at `01`; allocation runs under the data directory lock. Carrying a task preserves
its original ID across all later dates. Existing IDs remain unchanged.
The Telegram bot uses this automatic allocation.

New tasks store `created_at` at their first assignment. Edits and both carry
commands preserve it; the dashboard displays the full date and time in Myanmar
time. Legacy tasks without this field show “Created time unavailable” because
their original assignment time cannot be recovered reliably from `updated_at`.
Completed task IDs are locked across all daily records: reports, reassignment,
and manual carry are rejected, and automatic carry skips them, even when its
source is an older active copy.

```bash
python3 backend_python/update_tasks.py --date 2026-11-26 carry \
  --id task-001 --from-date 2026-11-25
```

The bot automatically carries unfinished tasks forward at 09:00 each day in Myanmar
time. A restart before 09:00 waits; a restart after 09:00 catches up missing tasks.
Only newly carried tasks trigger notifications, to the assignee's private chat
and the enabled group. New assignments retain the employee's Telegram user ID;
legacy usernames are matched against `TELEGRAM_STANDARD_USER_IDS`. Delivery
failures are logged without undoing carry; notifications are not automatically
retried after a restart. Use `/end_task` and select a finished task to mark it complete so it will
not carry forward. Manual carry is still available; completed tasks cannot be
carried. A carried task starts the new day's report history empty. When active
tasks roll into a date containing sample data, the sample entries are replaced
automatically.

Only users listed in `TELEGRAM_TASK_ASSIGN_USER_IDS` can use `/end_task`,
and only in chats listed in `TELEGRAM_ALLOWED_CHAT_IDS`.

Set `TELEGRAM_GROUP_CHAT_ID` to a negative group ID and
`TELEGRAM_GROUP_CHAT_ALLOWED=yes` to enable `/start`, `/task_lists`, and reports
for members posting in that group, even if not in the user allowlists. The enabled
group is automatically included in allowed chats. Assignment, completion, and
manual carry remain manager-only. Group report prompts request a reply to the bot.
`TELEGRAM_REPORT_RECEIVED_GROUP_CHAT=yes` also sends saved reports to the group,
in addition to `TELEGRAM_REPORT_RECEIVED_CHAT_IDS`, with duplicate recipients removed.

## Read the result

```bash
python3 backend_python/update_tasks.py --date 2026-11-25 list
```

Writes use a lock and atomic file replacement, preserving unrelated tasks and unknown fields. Invalid JSON is rejected without overwriting it. Commands return nonzero on errors. These commands do not send Telegram messages, schedule work, commit, push, or publish. After verifying the JSON, the agent must commit and push the changed daily file using its configured GitHub access for Pages to update. Keep private chat IDs and tokens out of public JSON.

Reports submitted through Telegram store the submitting user's ID, display name,
and available username in each report's `reported_by` object. This is independent
of the task assignee, including in group chats. The dashboard displays “Report by”
for each entry; older reports without this metadata show “Unknown (not recorded)”.
CLI callers can supply `--reporter-id`, `--reporter-name`, and
`--reporter-username`; these remain optional for existing integrations.
