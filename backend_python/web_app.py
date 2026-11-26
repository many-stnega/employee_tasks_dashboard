#!/usr/bin/env python3
"""Authenticated web dashboard application."""
import hmac
import json
import os
import secrets
import warnings
from datetime import date
from pathlib import Path

from flask import (
    Flask,
    abort,
    jsonify,
    redirect,
    render_template,
    request,
    send_from_directory,
    session,
    url_for,
)
from werkzeug.security import check_password_hash

with warnings.catch_warnings():
    warnings.simplefilter("ignore", DeprecationWarning)
    import crypt


PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEB_ROOT = PROJECT_ROOT / "web_dashboard"


def password_matches(password_hash: str, password: str) -> bool:
    if password_hash.startswith("$6$"):
        candidate = crypt.crypt(password, password_hash)
        return candidate is not None and hmac.compare_digest(candidate, password_hash)
    return check_password_hash(password_hash, password)


def create_app() -> Flask:
    username = os.environ.get("WEB_DASHBOARD_USERNAME", "")
    password_hash = os.environ.get("WEB_DASHBOARD_PASSWORD_HASH", "")
    secret_key = os.environ.get("WEB_DASHBOARD_SECRET_KEY", "")
    if not username or len(username) > 128:
        raise RuntimeError("WEB_DASHBOARD_USERNAME must be configured (1-128 characters).")
    if not password_hash:
        raise RuntimeError("WEB_DASHBOARD_PASSWORD_HASH must be configured.")
    if len(secret_key) < 32:
        raise RuntimeError("WEB_DASHBOARD_SECRET_KEY must contain at least 32 characters.")
    if password_hash.startswith("$6$"):
        if crypt.crypt("", password_hash) is None:
            raise RuntimeError("WEB_DASHBOARD_PASSWORD_HASH is not a valid SHA-512-crypt hash.")
    else:
        check_password_hash(password_hash, "")
    mobile_token = os.environ.get("MOBILE_API_TOKEN", "").strip()
    if mobile_token and len(mobile_token) < 32:
        raise RuntimeError("MOBILE_API_TOKEN must contain at least 32 characters.")

    app = Flask(__name__, template_folder=str(WEB_ROOT))
    app.config.update(
        MOBILE_API_TOKEN=mobile_token,
        SECRET_KEY=secret_key,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SECURE=True,
        SESSION_COOKIE_SAMESITE="Strict",
        PERMANENT_SESSION_LIFETIME=8 * 60 * 60,
        MAX_CONTENT_LENGTH=16 * 1024,
        TASKS_DATA_DIR=os.environ.get("TASKS_DATA_DIR", str(PROJECT_ROOT / "json_data_records")),
    )

    def csrf_token() -> str:
        token = session.get("csrf_token")
        if not token:
            token = secrets.token_urlsafe(32)
            session["csrf_token"] = token
        return token

    def authenticated() -> bool:
        return session.get("authenticated") is True

    @app.after_request
    def secure_response(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; script-src 'self'; style-src 'self'; "
            "img-src 'self' data:; connect-src 'self'; base-uri 'none'; "
            "form-action 'self'; frame-ancestors 'none'"
        )
        return response

    @app.get("/health")
    def health():
        return "ok\n"

    @app.route("/login", methods=["GET", "POST"])
    def login():
        error = None
        if request.method == "POST":
            submitted_token = request.form.get("csrf_token", "")
            expected_token = session.get("csrf_token", "")
            if not submitted_token or not expected_token or not hmac.compare_digest(
                submitted_token, expected_token
            ):
                abort(400, description="Invalid form token.")
            submitted_username = request.form.get("username", "")
            submitted_password = request.form.get("password", "")
            password_valid = password_matches(password_hash, submitted_password)
            if hmac.compare_digest(submitted_username, username) and password_valid:
                session.clear()
                session["authenticated"] = True
                session.permanent = True
                csrf_token()
                return redirect(url_for("dashboard"))
            error = "Username or password is incorrect."
        return render_template("login.html", error=error, csrf_token=csrf_token()), (
            401 if error else 200
        )

    @app.get("/")
    def dashboard():
        if not authenticated():
            return redirect(url_for("login"))
        return render_template("index.html", csrf_token=csrf_token())

    @app.post("/logout")
    def logout():
        if not authenticated():
            return redirect(url_for("login"))
        submitted_token = request.form.get("csrf_token", "")
        if not hmac.compare_digest(submitted_token, session.get("csrf_token", "")):
            abort(400, description="Invalid form token.")
        session.clear()
        return redirect(url_for("login"))

    def mobile_authorized() -> bool:
        token = app.config.get("MOBILE_API_TOKEN", "")
        supplied = request.headers.get("X-Mobile-Token", "")
        return bool(token) and bool(supplied) and hmac.compare_digest(token, supplied)

    def valid_day_key(key: str) -> bool:
        try:
            parsed = date.fromisoformat(key)
        except ValueError:
            return False
        return parsed.isoformat() == key and 2000 <= parsed.year <= 2100

    def daily_file(key: str):
        path = Path(app.config["TASKS_DATA_DIR"]) / f"{key}.json"
        if not path.is_file():
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
        if (
            not isinstance(data, dict)
            or data.get("date") != key
            or not isinstance(data.get("tasks"), list)
        ):
            return None
        return data

    @app.get("/api/mobile/dates")
    def mobile_dates():
        if not mobile_authorized():
            abort(401)
        folder = Path(app.config["TASKS_DATA_DIR"])
        dates = sorted(
            path.stem for path in folder.glob("*.json")
            if valid_day_key(path.stem) and daily_file(path.stem) is not None
        )
        return jsonify({"dates": dates})

    @app.get("/api/mobile/data/<date_key>")
    def mobile_day(date_key: str):
        if not mobile_authorized():
            abort(401)
        if not valid_day_key(date_key):
            abort(400)
        data = daily_file(date_key)
        if data is None:
            abort(404)
        return jsonify(data)

    @app.get("/<path:asset>")
    def dashboard_asset(asset: str):
        if asset.startswith("api/"):
            abort(404)
        if asset == "login.css":
            return send_from_directory(WEB_ROOT, asset)
        if not authenticated():
            return redirect(url_for("login"))
        if asset == "login" or asset.startswith("login/"):
            abort(404)
        if asset.startswith("data/"):
            return send_from_directory(app.config["TASKS_DATA_DIR"], asset[5:])
        return send_from_directory(WEB_ROOT, asset)

    return app


app = create_app()
