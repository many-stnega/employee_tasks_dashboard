#!/usr/bin/env python3
"""Maintain daily dashboard JSON files. Python 3.9+, Linux, standard library only."""
import argparse
from contextlib import contextmanager
from datetime import date, datetime, timedelta, timezone
import fcntl
import json
import os
from pathlib import Path
import tempfile
import re

MMT = timezone(timedelta(hours=6, minutes=30))
DEFAULT_DATA = Path(
    os.environ.get(
        'TASKS_DATA_DIR',
        Path(__file__).resolve().parents[1] / 'json_data_records',
    )
)


def day(value):
    try:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() != value or not 2000 <= parsed.year <= 2100:
            raise ValueError()
        return value
    except ValueError:
        raise argparse.ArgumentTypeError('Use a date in YYYY-MM-DD format (2000–2100).')


def nonempty(value):
    if not value.strip():
        raise argparse.ArgumentTypeError('Value must not be empty.')
    return value


def username(value):
    value = value.lstrip('@')
    if not re.fullmatch(r'[a-zA-Z0-9_]{5,32}', value):
        raise argparse.ArgumentTypeError('Use a Telegram username, without a profile URL.')
    return value


def timestamp(value):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('Timestamp must include a timezone.')
    return parsed


def load(folder, key):
    path = folder / f'{key}.json'
    if not path.exists():
        return {'date': key, 'tasks': []}
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict) or data.get('date') != key or not isinstance(data.get('tasks'), list):
        raise ValueError(f'Invalid daily file: {path}')
    ids = set()
    for task in data['tasks']:
        if not isinstance(task, dict) or not isinstance(task.get('id'), str) or not task['id'] or task['id'] in ids:
            raise ValueError(f'Invalid or duplicate task ID in {path}')
        ids.add(task['id'])
        if not isinstance(task.get('description'), str):
            raise ValueError(f'Missing description for {task["id"]}')
        if not (
            isinstance(task.get('task'), str)
            or isinstance(task.get('repo'), dict) and isinstance(task['repo'].get('name'), str)
        ):
            raise ValueError(f'Missing task name for {task["id"]}')
        assigned_to = task.get('assigned_to')
        if not (
            isinstance(assigned_to, str)
            or isinstance(assigned_to, dict)
            and (
                isinstance(assigned_to.get('username'), str)
                or isinstance(assigned_to.get('name'), str)
            )
        ):
            raise ValueError(f'Invalid assigned_to for {task["id"]}')
        report = task.get('employee_report')
        if report is not None:
            if not isinstance(report, dict) or not isinstance(report.get('description'), str):
                raise ValueError(f'Invalid employee report for {task["id"]}')
            timestamp(report.get('reported_at', ''))
    return data


@contextmanager
def locked(folder):
    folder.mkdir(parents=True, exist_ok=True)
    # Lock the directory itself: no lock file is published with the data.
    descriptor = os.open(folder, os.O_RDONLY)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield
    finally:
        os.close(descriptor)


def write(folder, data):
    target = folder / f'{data["date"]}.json'
    temp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=folder, prefix='.task-', suffix='.tmp', delete=False) as stream:
            temp = Path(stream.name)
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temp, 0o644)
        os.replace(temp, target)
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, default=DEFAULT_DATA)
    parser.add_argument('--date', type=day, default=datetime.now(MMT).date().isoformat())
    commands = parser.add_subparsers(dest='command', required=True)
    assign_task = commands.add_parser('assign_task', help='Create or update an assignment, preserving its employee report.')
    assign_task.add_argument('--id', required=True, type=nonempty)
    assign_task.add_argument('--task', required=True, type=nonempty, help='Task name displayed on the card.')
    assign_task.add_argument('--username', required=True, type=username)
    assign_task.add_argument('--description', required=True, type=nonempty)
    report = commands.add_parser('report', help='Record an employee reply for an existing task.')
    report.add_argument('--id', required=True, type=nonempty)
    report.add_argument('--description', required=True, type=nonempty)
    report.add_argument('--reported-at', help='ISO timestamp with timezone; defaults to now.')
    carry = commands.add_parser('carry', help='Copy one assignment from an earlier day, without its old report.')
    carry.add_argument('--id', required=True, type=nonempty)
    carry.add_argument('--from-date', required=True, type=day)
    commands.add_parser('list', help='Print this day’s JSON without changing it.')
    args = parser.parse_args()
    try:
        with locked(args.data_dir):
            data = load(args.data_dir, args.date)
            if args.command == 'list':
                print(json.dumps(data, ensure_ascii=False, indent=2))
                return
            if data.get('demo'):
                raise ValueError('Sample file: choose a date without sample data before updating it.')
            now = datetime.now(MMT).isoformat(timespec='seconds')
            task = next((item for item in data['tasks'] if item['id'] == args.id), None)
            if args.command == 'assign_task':
                if task is None:
                    task = {'id': args.id}
                    data['tasks'].append(task)
                task.pop('repo', None)
                task['task'] = args.task
                task['assigned_to'] = {'username': args.username}
                task['description'] = args.description
            elif args.command == 'report':
                if task is None:
                    raise ValueError('Task not found for this date. Create or carry the assignment first.')
                reported = timestamp(args.reported_at or now).astimezone(MMT)
                if reported.date().isoformat() != args.date:
                    raise ValueError('Report timestamp must fall on --date in Myanmar time.')
                previous_report = task.get('employee_report')
                previous_description = (
                    previous_report.get('description', '').strip()
                    if isinstance(previous_report, dict)
                    else ''
                )
                combined_description = (
                    f'{previous_description}\n\n{args.description}'
                    if previous_description
                    else args.description
                )
                task['employee_report'] = {
                    'description': combined_description,
                    'reported_at': reported.isoformat(timespec='seconds'),
                }
            elif args.command == 'carry':
                if args.from_date >= args.date:
                    raise ValueError('--from-date must be earlier than --date.')
                if task is not None:
                    print(f'Task {args.id} already exists for {args.date}; unchanged.')
                    return
                source = load(args.data_dir, args.from_date)
                if source.get('demo'):
                    raise ValueError('Cannot carry a sample assignment into real records.')
                original = next((item for item in source['tasks'] if item['id'] == args.id), None)
                if original is None:
                    raise ValueError('Source task not found.')
                task_name = original.get('task')
                if task_name is None:
                    task_name = original['repo']['name']
                assigned_to = original['assigned_to']
                if isinstance(assigned_to, dict):
                    username_value = assigned_to.get('username')
                    task_assignee = (
                        {'username': username_value}
                        if username_value
                        else {'name': assigned_to.get('name', 'Unknown')}
                    )
                else:
                    task_assignee = {'username': assigned_to.lstrip('@')}
                task = {
                    'id': original['id'],
                    'task': task_name,
                    'assigned_to': task_assignee,
                    'description': original['description'],
                }
                data['tasks'].append(task)
            task['updated_at'] = now
            data['updated_at'] = now
            data['demo'] = False
            target = write(args.data_dir, data)
            print(f'Saved {args.id}: {target}')
    except (OSError, ValueError, TypeError) as error:
        parser.exit(1, f'Error: {error}\n')


if __name__ == '__main__':
    main()
