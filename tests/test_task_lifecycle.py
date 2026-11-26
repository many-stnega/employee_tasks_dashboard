import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from backend_python import bot


SCRIPT = Path(__file__).resolve().parents[1] / 'backend_python' / 'update_tasks.py'


class TaskLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)

    def run_command(self, day, *args, success=True):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--data-dir', str(self.folder), '--date', day, *args],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def assign(self, day, task_id='20260901-01', success=True):
        return self.run_command(day, 'assign_task', '--id', task_id, '--task', 'Task',
                                '--username', 'employee', '--description', 'Description', success=success)

    def read(self, day):
        return json.loads((self.folder / f'{day}.json').read_text())

    def test_created_time_survives_edits_reports_and_two_months_of_carry(self):
        self.assign('2026-09-01')
        data = self.read('2026-09-01')
        self.assertTrue(data['tasks'][0]['created_at'])
        original = '2026-09-01T09:12:30+06:30'
        data['tasks'][0]['created_at'] = original
        (self.folder / '2026-09-01.json').write_text(json.dumps(data))
        self.assign('2026-09-01')
        self.run_command('2026-09-01', 'report', '--id', '20260901-01', '--description', 'Progress',
                         '--reported-at', '2026-09-01T10:00:00+06:30')
        self.run_command('2026-10-01', 'carry', '--id', '20260901-01', '--from-date', '2026-09-01')
        self.run_command('2026-11-01', 'carry_forward', '--from-date', '2026-10-01')
        for day in ('2026-09-01', '2026-10-01', '2026-11-01'):
            task = self.read(day)['tasks'][0]
            self.assertEqual(task['created_at'], original)
            self.assertNotEqual(task['updated_at'], original)

    def test_completed_task_cannot_be_changed_or_revived_from_older_copy(self):
        self.assign('2026-09-01')
        self.run_command('2026-09-02', 'carry_forward', '--from-date', '2026-09-01')
        self.run_command('2026-09-02', 'end_task', '--id', '20260901-01')
        before = {p.name: p.read_bytes() for p in self.folder.glob('*.json')}
        for day in ('2026-09-01', '2026-09-02', '2026-09-03'):
            self.assign(day, success=False)
            result = self.run_command(day, 'report', '--id', '20260901-01', '--description', 'Late',
                                     '--reported-at', f'{day}T12:00:00+06:30', success=False)
            self.assertIn('completed and cannot be modified', result.stderr)
        self.run_command('2026-09-03', 'carry', '--id', '20260901-01', '--from-date', '2026-09-01', success=False)
        self.run_command('2026-09-03', 'carry_forward', '--from-date', '2026-09-01')
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.folder.glob('*.json')})

    def test_completed_task_keyboard_has_no_report_button(self):
        keyboard = bot.task_detail_keyboard({'status': 'completed'})
        self.assertEqual([button.callback_data for row in keyboard.inline_keyboard for button in row], ['task_list_back'])
        active = bot.task_detail_keyboard({'status': 'active'})
        self.assertIn('task_list_report', [button.callback_data for row in active.inline_keyboard for button in row])

    def test_legacy_created_time_is_not_invented_during_carry(self):
        self.assign('2026-09-01')
        data = self.read('2026-09-01')
        del data['tasks'][0]['created_at']
        (self.folder / '2026-09-01.json').write_text(json.dumps(data))
        self.run_command('2026-09-02', 'carry_forward', '--from-date', '2026-09-01')
        self.assertIsNone(self.read('2026-09-02')['tasks'][0]['created_at'])
