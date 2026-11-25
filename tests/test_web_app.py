import os
import unittest
from pathlib import Path
import warnings
from unittest.mock import patch

from werkzeug.security import generate_password_hash

with warnings.catch_warnings():
    warnings.simplefilter("ignore", DeprecationWarning)
    import crypt

os.environ.update({
    "WEB_DASHBOARD_USERNAME": "test-user",
    "WEB_DASHBOARD_PASSWORD_HASH": generate_password_hash("test-password"),
    "WEB_DASHBOARD_SECRET_KEY": "test-session-secret-key-that-is-long-enough",
    "TASKS_DATA_DIR": str(Path(__file__).resolve().parents[1] / "json_data_records"),
})

from backend_python.web_app import create_app


class DashboardAuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.client = create_app().test_client()

    def csrf_token(self):
        response = self.client.get("/login")
        self.assertEqual(response.status_code, 200)
        body = response.get_data(as_text=True)
        return body.split('name="csrf_token" value="', 1)[1].split('"', 1)[0]

    def sign_in(self):
        self.client.post("/login", data={
            "csrf_token": self.csrf_token(),
            "username": "test-user",
            "password": "test-password",
        })

    def test_dashboard_and_log_data_require_authentication(self):
        self.assertEqual(self.client.get("/").status_code, 302)
        self.assertEqual(self.client.get("/data/2026-11-25.json").status_code, 302)
        stylesheet = self.client.get("/login.css")
        self.assertEqual(stylesheet.status_code, 200)
        stylesheet.close()

    def test_valid_login_reads_dashboard_and_protects_session(self):
        response = self.client.post("/login", data={
            "csrf_token": self.csrf_token(),
            "username": "test-user",
            "password": "test-password",
        })
        self.assertEqual(response.status_code, 302)
        dashboard = self.client.get("/")
        self.assertEqual(dashboard.status_code, 200)
        self.assertIn(b'name="csrf_token"', dashboard.data)
        log = self.client.get("/data/2026-11-25.json")
        self.assertEqual(log.status_code, 200)
        log.close()
        cookie = self.client.get_cookie("session")
        self.assertTrue(cookie.secure)
        self.assertTrue(cookie.http_only)

    def test_invalid_credentials_do_not_create_session(self):
        response = self.client.post("/login", data={
            "csrf_token": self.csrf_token(),
            "username": "test-user",
            "password": "wrong-password",
        })
        self.assertEqual(response.status_code, 401)
        self.assertEqual(self.client.get("/").status_code, 302)
        self.assertEqual(self.client.get("/data/2026-11-25.json").status_code, 302)

    def test_openssl_sha512_crypt_password_hash(self):
        password_hash = crypt.crypt(
            "test-password",
            crypt.mksalt(crypt.METHOD_SHA512, rounds=500000),
        )
        self.assertIsNotNone(password_hash)
        with patch.dict(os.environ, {"WEB_DASHBOARD_PASSWORD_HASH": password_hash}):
            client = create_app().test_client()
            token_response = client.get("/login")
            token = token_response.get_data(as_text=True).split(
                'name="csrf_token" value="', 1
            )[1].split('"', 1)[0]
            response = client.post("/login", data={
                "csrf_token": token,
                "username": "test-user",
                "password": "test-password",
            })
        self.assertEqual(response.status_code, 302)

    def test_logout_requires_csrf_token_and_clears_session(self):
        self.sign_in()
        dashboard = self.client.get("/")
        body = dashboard.get_data(as_text=True)
        token = body.split('name="csrf_token" value="', 1)[1].split('"', 1)[0]
        self.assertEqual(self.client.post("/logout", data={"csrf_token": "bad"}).status_code, 400)
        self.assertEqual(self.client.post("/logout", data={"csrf_token": token}).status_code, 302)
        self.assertEqual(self.client.get("/data/2026-11-25.json").status_code, 302)

    def test_login_requires_csrf_token(self):
        response = self.client.post("/login", data={
            "username": "test-user",
            "password": "test-password",
        })
        self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
