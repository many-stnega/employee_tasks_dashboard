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

```bash
python3 backend_python/update_tasks.py --date 2026-11-26 carry \
  --id task-001 --from-date 2026-11-25
```

The bot automatically carries unfinished tasks forward each day in Myanmar
time. Use `/end_task` and select a finished task to mark it complete so it will
not carry forward. Manual carry is still available; completed tasks cannot be
carried. A carried task starts the new day's report history empty. When active
tasks roll into a date containing sample data, the sample entries are replaced
automatically.

## Read the result

```bash
python3 backend_python/update_tasks.py --date 2026-11-25 list
```

Writes use a lock and atomic file replacement, preserving unrelated tasks and unknown fields. Invalid JSON is rejected without overwriting it. Commands return nonzero on errors. These commands do not send Telegram messages, schedule work, commit, push, or publish. After verifying the JSON, the agent must commit and push the changed daily file using its configured GitHub access for Pages to update. Keep private chat IDs and tokens out of public JSON.
