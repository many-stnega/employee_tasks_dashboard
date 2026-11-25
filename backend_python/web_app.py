#!/usr/bin/env python3
"""Authenticated web dashboard application."""
import hmac
import os
import secrets
from pathlib import Path

from flask import (
    Flask,
    abort,
    redirect,
    render_template,
    request,
    send_from_directory,
    session,
    url_for,
)
from werkzeug.security import check_password_hash


PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEB_ROOT = PROJECT_ROOT / "web_dashboard"


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
    check_password_hash(password_hash, "")

    app = Flask(__name__, template_folder=str(WEB_ROOT))
    app.config.update(
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
            password_matches = check_password_hash(password_hash, submitted_password)
            if hmac.compare_digest(submitted_username, username) and password_matches:
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

    @app.get("/<path:asset>")
    def dashboard_asset(asset: str):
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
