import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "backend_python" / "update_tasks.py"


class DatePrefixedTaskIdTests(unittest.TestCase):
    def test_ids_start_at_one_and_remain_unique_across_dates_and_concurrent_writes(self):
        with tempfile.TemporaryDirectory() as folder:
            def command(day, extra=()):
                return [sys.executable, str(SCRIPT), "--data-dir", folder, "--date", day,
                        "assign_task", "--task", "Test", "--username", "employee",
                        "--description", "Description", *extra]

            subprocess.run(command("2026-11-25", ["--id", "legacy-task"]), check=True, capture_output=True)
            first = subprocess.run(command("2026-11-25"), check=True, capture_output=True, text=True)
            self.assertTrue(first.stdout.startswith("Saved 20261125-01:"))
            second = subprocess.run(command("2026-11-25"), check=True, capture_output=True, text=True)
            self.assertTrue(second.stdout.startswith("Saved 20261125-02:"))
            processes = [subprocess.Popen(command("2026-11-26"), stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(4)]
            for process in processes:
                _, errors = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 0, errors)
            data = json.loads((Path(folder) / "2026-11-26.json").read_text())
            self.assertEqual({task['id'] for task in data['tasks']}, {"20261126-01", "20261126-02", "20261126-03", "20261126-04"})
            previous = json.loads((Path(folder) / "2026-11-25.json").read_text())
            self.assertEqual([task['id'] for task in previous['tasks']], ["legacy-task", "20261125-01", "20261125-02"])

            # Both manual and automatic carry preserve the original assignment ID.
            subprocess.run([sys.executable, str(SCRIPT), "--data-dir", folder,
                            "--date", "2026-11-26", "carry", "--id", "20261125-01",
                            "--from-date", "2026-11-25"], check=True, capture_output=True)
            subprocess.run([sys.executable, str(SCRIPT), "--data-dir", folder,
                            "--date", "2026-11-30", "carry_forward",
                            "--from-date", "2026-11-26"], check=True, capture_output=True)
            carried = json.loads((Path(folder) / "2026-11-30.json").read_text())
            self.assertIn("20261125-01", {task['id'] for task in carried['tasks']})
            fresh = subprocess.run(command("2026-11-30"), check=True, capture_output=True, text=True)
            self.assertTrue(fresh.stdout.startswith("Saved 20261130-01:"))

            # Sequence grows beyond two digits without truncation.
            subprocess.run(command("2026-11-30", ["--id", "20261130-99"]), check=True, capture_output=True)
            hundredth = subprocess.run(command("2026-11-30"), check=True, capture_output=True, text=True)
            self.assertTrue(hundredth.stdout.startswith("Saved 20261130-100:"))
