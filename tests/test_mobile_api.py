import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from werkzeug.security import generate_password_hash

os.environ.update({
    "WEB_DASHBOARD_USERNAME": "test-user",
    "WEB_DASHBOARD_PASSWORD_HASH": generate_password_hash("test-password"),
    "WEB_DASHBOARD_SECRET_KEY": "test-session-secret-key-that-is-long-enough",
})

from backend_python.web_app import create_app

TOKEN = "mobile-token-that-is-long-enough-for-tests-1234"


class MobileApiTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        folder = Path(self.tmp.name)
        payload = {"date": "2026-11-26", "tasks": [{"id": "a"}], "demo": False}
        (folder / "2026-11-26.json").write_text(json.dumps(payload), encoding="utf-8")
        (folder / "notes.txt").write_text("ignore", encoding="utf-8")
        env = {
            "WEB_DASHBOARD_USERNAME": "test-user",
            "WEB_DASHBOARD_PASSWORD_HASH": generate_password_hash("test-password"),
            "WEB_DASHBOARD_SECRET_KEY": "test-session-secret-key-that-is-long-enough",
            "TASKS_DATA_DIR": str(folder),
            "MOBILE_API_TOKEN": TOKEN,
        }
        with patch.dict(os.environ, env):
            self.client = create_app().test_client()

    def tearDown(self):
        self.tmp.cleanup()

    def test_requires_token(self):
        for path in ("/api/mobile/dates", "/api/mobile/data/2026-11-26"):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 401)
                self.assertEqual(
                    self.client.get(path, headers={"X-Mobile-Token": "wrong"}).status_code,
                    401,
                )

    def test_lists_only_valid_daily_files(self):
        response = self.client.get(
            "/api/mobile/dates", headers={"X-Mobile-Token": TOKEN}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"dates": ["2026-11-26"]})

    def test_returns_daily_json(self):
        response = self.client.get(
            "/api/mobile/data/2026-11-26", headers={"X-Mobile-Token": TOKEN}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["date"], "2026-11-26")
        self.assertEqual(response.get_json()["tasks"], [{"id": "a"}])

    def test_rejects_invalid_and_missing_dates(self):
        headers = {"X-Mobile-Token": TOKEN}
        self.assertEqual(
            self.client.get("/api/mobile/data/not-a-date", headers=headers).status_code,
            400,
        )
        self.assertEqual(
            self.client.get("/api/mobile/data/2026-11-25", headers=headers).status_code,
            404,
        )

    def test_short_token_is_rejected_at_startup(self):
        env = {
            "WEB_DASHBOARD_USERNAME": "test-user",
            "WEB_DASHBOARD_PASSWORD_HASH": generate_password_hash("test-password"),
            "WEB_DASHBOARD_SECRET_KEY": "test-session-secret-key-that-is-long-enough",
            "MOBILE_API_TOKEN": "short",
        }
        with patch.dict(os.environ, env):
            with self.assertRaises(RuntimeError):
                create_app()


if __name__ == "__main__":
    unittest.main()
