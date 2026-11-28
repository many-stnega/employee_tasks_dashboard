#!/usr/bin/env python3
"""Editable runtime access settings for the Telegram bot and mobile app.

Stored in a separate JSON file (never in .env) so the mobile admin screen can
update allowlists and carry-notification weekdays without restarting the bot.
If the file does not exist yet, the current .env allowlists are used as the
initial view; the first save writes them into the file.
"""
import json
import os
import tempfile
from pathlib import Path

WEEKDAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
USER_ROLES = ("standard", "assign", "allowed_chat", "report_received")
GROUP_ROLES = ("allowed_chat", "report_received")


def settings_path() -> Path:
    configured = os.environ.get("MOBILE_SETTINGS_PATH", "").strip()
    if configured:
        return Path(configured).expanduser()
    data_dir = os.environ.get("TASKS_DATA_DIR", "").strip()
    if data_dir:
        # In Docker this is bind-mounted from ./json_data_records, so settings
        # survive container recreation without touching .env.
        return Path(data_dir) / "mobile_settings.json"
    return Path(__file__).resolve().parent.parent / "mobile_settings.json"


def _positive_ids(name: str) -> set[int]:
    result = set()
    for part in os.environ.get(name, "").replace("\n", ",").split(","):
        part = part.strip()
        if not part:
            continue
        try:
            value = int(part)
        except ValueError:
            continue
        if value > 0:
            result.add(value)
    return result


def seed_from_env() -> dict:
    """Build an initial editable view from the existing .env allowlists."""
    standard = _positive_ids("TELEGRAM_STANDARD_USER_IDS")
    assign = _positive_ids("TELEGRAM_TASK_ASSIGN_USER_IDS")
    allowed_chat = set()
    for name in ("TELEGRAM_ALLOWED_CHAT_IDS", "TELEGRAM_REPORT_RECEIVED_CHAT_IDS"):
        for part in os.environ.get(name, "").replace("\n", ",").split(","):
            part = part.strip()
            if part.lstrip("-").isdigit():
                allowed_chat.add(int(part))
    report_received = {
        int(part.strip())
        for part in os.environ.get("TELEGRAM_REPORT_RECEIVED_CHAT_IDS", "").replace("\n", ",").split(",")
        if part.strip().lstrip("-").isdigit()
    }
    users = [
        {
            "id": user_id,
            "username": "",
            "name": "",
            "roles": {
                "standard": user_id in standard,
                "assign": user_id in assign,
                "allowed_chat": user_id in allowed_chat,
                "report_received": user_id in report_received,
            },
        }
        for user_id in sorted(standard | assign | {
            value for value in allowed_chat if value > 0
        })
    ]
    groups = []
    group_id = os.environ.get("TELEGRAM_GROUP_CHAT_ID", "").strip()
    if group_id.lstrip("-").isdigit() and int(group_id) < 0:
        groups.append({
            "id": int(group_id),
            "name": "",
            "roles": {
                "allowed_chat": os.environ.get("TELEGRAM_GROUP_CHAT_ALLOWED", "no").strip().lower() == "yes",
                "report_received": os.environ.get("TELEGRAM_REPORT_RECEIVED_GROUP_CHAT", "no").strip().lower() == "yes",
            },
        })
    return {
        "users": users,
        "groups": groups,
        "carry_notify_weekdays": list(WEEKDAYS),
    }


def load_settings() -> dict | None:
    """Return validated settings, or None when the file has never been saved."""
    path = settings_path()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return validate(data)
    except (OSError, json.JSONDecodeError, ValueError):
        return None


def settings_view() -> dict:
    return load_settings() or seed_from_env()


def validate(data: object) -> dict:
    """Normalise and reject malformed input before it is persisted."""
    if not isinstance(data, dict):
        raise ValueError("Settings must be an object.")
    users = data.get("users", [])
    groups = data.get("groups", [])
    weekdays = data.get("carry_notify_weekdays", [])
    if not isinstance(users, list) or len(users) > 500:
        raise ValueError("users must be a list of at most 500 entries.")
    if not isinstance(groups, list) or len(groups) > 100:
        raise ValueError("groups must be a list of at most 100 entries.")
    if not isinstance(weekdays, list) or any(day not in WEEKDAYS for day in weekdays):
        raise ValueError("carry_notify_weekdays contains an unknown weekday.")

    clean_users = []
    seen_users = set()
    for entry in users:
        if not isinstance(entry, dict):
            raise ValueError("Each user must be an object.")
        try:
            user_id = int(entry["id"])
        except (KeyError, TypeError, ValueError):
            raise ValueError("Each user needs a numeric id.") from None
        if user_id <= 0 or user_id in seen_users:
            raise ValueError("User ids must be positive and unique.")
        seen_users.add(user_id)
        roles = entry.get("roles", {})
        if not isinstance(roles, dict):
            raise ValueError("User roles must be an object.")
        clean_users.append({
            "id": user_id,
            "username": str(entry.get("username", "")).strip(),
            "name": str(entry.get("name", "")).strip(),
            "roles": {role: bool(roles.get(role, False)) for role in USER_ROLES},
        })

    clean_groups = []
    seen_groups = set()
    for entry in groups:
        if not isinstance(entry, dict):
            raise ValueError("Each group must be an object.")
        try:
            group_id = int(entry["id"])
        except (KeyError, TypeError, ValueError):
            raise ValueError("Each group needs a numeric id.") from None
        if group_id >= 0 or group_id in seen_groups:
            raise ValueError("Group ids must be negative and unique.")
        seen_groups.add(group_id)
        roles = entry.get("roles", {})
        if not isinstance(roles, dict):
            raise ValueError("Group roles must be an object.")
        clean_groups.append({
            "id": group_id,
            "name": str(entry.get("name", "")).strip(),
            "roles": {role: bool(roles.get(role, False)) for role in GROUP_ROLES},
        })

    return {
        "users": clean_users,
        "groups": clean_groups,
        "carry_notify_weekdays": [day for day in WEEKDAYS if day in weekdays],
    }


def save_settings(data: object) -> dict:
    """Validate then atomically persist. Returns the normalised document."""
    clean = validate(data)
    path = settings_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent, prefix=".mobile_settings-", delete=False
    ) as handle:
        json.dump(clean, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temp_name = handle.name
    os.replace(temp_name, path)
    return clean


def effective_config() -> dict:
    """Sets used by the running bot, with env fallback before first save."""
    settings = load_settings()
    if settings is None:
        seed = seed_from_env()
        settings = validate(seed)
    users = settings["users"]
    groups = settings["groups"]
    chat_ids = set()
    for user in users:
        if user["roles"]["allowed_chat"]:
            chat_ids.add(user["id"])
    group_ids = set()
    for group in groups:
        if group["roles"]["allowed_chat"]:
            group_ids.add(group["id"])
            chat_ids.add(group["id"])
    report_received = {
        user["id"] for user in users if user["roles"]["report_received"]
    }
    report_received |= {
        group["id"] for group in groups if group["roles"]["report_received"]
    }
    return {
        "task_assign_user_ids": {
            user["id"] for user in users if user["roles"]["assign"]
        },
        "standard_user_ids": {
            user["id"] for user in users if user["roles"]["standard"]
        },
        "allowed_chat_ids": chat_ids,
        "report_received_chat_ids": report_received,
        "group_chat_ids": group_ids,
        "group_chat_allowed": bool(group_ids),
        "report_received_group_chat": bool(
            {group["id"] for group in groups if group["roles"]["report_received"]}
        ),
        "carry_notify_weekdays": set(settings["carry_notify_weekdays"]),
    }
