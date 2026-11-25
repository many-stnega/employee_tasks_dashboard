#!/usr/bin/env python3
"""Telegram bot entry point for the employee tasks dashboard."""
import logging
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlparse

from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    ConversationHandler,
    MessageHandler,
    filters,
)

TASK_ID, TASK_NAME, TASK_EMPLOYEE, TASK_USERNAME, TASK_URL, TASK_REPLACE_SAMPLE, TASK_DESCRIPTION = range(7)
TASK_ASSIGNMENT_STEPS = (
    TASK_ID,
    TASK_NAME,
    TASK_EMPLOYEE,
    TASK_USERNAME,
    TASK_URL,
    TASK_REPLACE_SAMPLE,
    TASK_DESCRIPTION,
)
TASK_ASSIGNMENT_PROMPTS = {
    TASK_ID: "Enter a unique task ID:",
    TASK_NAME: "What is the task or repository name?",
    TASK_EMPLOYEE: "Who is assigned to this task? Enter their name:",
    TASK_USERNAME: "Enter their Telegram username, or '-' to skip:",
    TASK_URL: "Enter the task or repository URL, or '-' to skip:",
    TASK_REPLACE_SAMPLE: "Replace today's sample tasks? Reply yes or no:",
    TASK_DESCRIPTION: "Describe the task. You can include multiple lines:",
}


def task_assignment_key(update: Update) -> str:
    return f"task_assignment:{update.effective_chat.id}"


def allowed_ids(variable, *, positive_only=False):
    value = os.environ.get(variable, "").strip()
    if not value:
        return set()

    try:
        result = {int(item.strip()) for item in value.split(",")}
    except ValueError as error:
        raise ValueError(f"{variable} must contain only numeric Telegram IDs.") from error

    if not result or (positive_only and any(item <= 0 for item in result)) or 0 in result:
        raise ValueError(f"{variable} contains an invalid Telegram ID.")
    return result


def authorized(update: Update, user_ids: set[int], chat_ids: set[int]) -> bool:
    user = update.effective_user
    chat = update.effective_chat
    return user is not None and chat is not None and user.id in user_ids and chat.id in chat_ids


def parse_report(text: str) -> dict[str, str]:
    fields = {}
    description_lines = None
    for line in text.splitlines()[1:]:
        if description_lines is not None:
            description_lines.append(line)
            continue
        if ":" not in line:
            if line.strip():
                raise ValueError("Use `ID:` and `Description:` fields in /report.")
            continue
        key, value = line.split(":", 1)
        key = key.strip().lower()
        if key == "description":
            description_lines = [value.strip()] if value.strip() else []
        elif key == "id":
            if "id" in fields:
                raise ValueError("Duplicate field: id.")
            fields["id"] = value.strip()
        else:
            raise ValueError(f"Unknown field: {key}.")

    if description_lines is not None:
        fields["description"] = "\n".join(description_lines).strip()
    missing = {"id", "description"} - fields.keys()
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(sorted(missing))}.")
    if not fields["id"] or not fields["description"]:
        raise ValueError("ID and description must not be empty.")
    return fields


def parse_carry(text: str) -> dict[str, str]:
    fields = {}
    for line in text.splitlines()[1:]:
        if not line.strip():
            continue
        if ":" not in line:
            raise ValueError("Use `ID:` and `From date:` fields in /carry.")
        key, value = line.split(":", 1)
        key = key.strip().lower()
        if key not in {"id", "from date"}:
            raise ValueError(f"Unknown field: {key}.")
        if key in fields:
            raise ValueError(f"Duplicate field: {key}.")
        fields[key] = value.strip()

    missing = {"id", "from date"} - fields.keys()
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(sorted(missing))}.")
    if not fields["id"] or not fields["from date"]:
        raise ValueError("ID and from date must not be empty.")
    return fields


async def run_task_update(
    update: Update,
    command: list[str],
    task_id: str,
    action: str,
) -> None:
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        logging.exception("Could not run task %s command.", action)
        await update.effective_message.reply_text(f"Could not {action} task: {error}")
        return
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        logging.error("Could not %s task: %s", action, detail)
        await update.effective_message.reply_text(f"Could not {action} task: {detail}")
        return
    if action == "carry" and "already exists" in result.stdout.lower():
        await update.effective_message.reply_text(result.stdout.strip())
        return
    past_tense = {"assign": "assigned", "report": "reported", "carry": "carried"}
    await update.effective_message.reply_text(f"Task {past_tense[action]}: {task_id}.")


async def task_assign_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not authorized(
        update,
        context.bot_data["task_assign_user_ids"],
        context.bot_data["allowed_chat_ids"],
    ):
        await update.effective_message.reply_text(
            "You are not authorized to assign tasks in this chat."
        )
        return ConversationHandler.END

    state_key = task_assignment_key(update)
    context.user_data[state_key] = {}
    context.user_data[f"{state_key}:step"] = TASK_ID
    await update.effective_message.reply_text(TASK_ASSIGNMENT_PROMPTS[TASK_ID])
    return TASK_ID


async def task_assign_answer(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    if not authorized(
        update,
        context.bot_data["task_assign_user_ids"],
        context.bot_data["allowed_chat_ids"],
    ):
        state_key = task_assignment_key(update)
        context.user_data.pop(state_key, None)
        context.user_data.pop(f"{state_key}:step", None)
        await update.effective_message.reply_text(
            "You are not authorized to assign tasks in this chat."
        )
        return ConversationHandler.END

    answer = update.effective_message.text.strip()
    state_key = task_assignment_key(update)
    step = context.user_data[f"{state_key}:step"]
    fields = context.user_data[state_key]

    if not answer:
        await update.effective_message.reply_text("Please enter a non-empty answer.")
        return step
    if step == TASK_USERNAME and answer != "-":
        answer = answer.removeprefix("@")
        if not re.fullmatch(r"[a-zA-Z0-9_]{5,32}", answer):
            await update.effective_message.reply_text(
                "Enter a valid Telegram username (5-32 letters, numbers, or underscores), or '-' to skip."
            )
            return step
    elif step == TASK_URL and answer != "-":
        parsed = urlparse(answer)
        if (
            parsed.scheme not in {"http", "https"}
            or not parsed.hostname
            or parsed.username
            or parsed.password
        ):
            await update.effective_message.reply_text(
                "Enter a valid HTTP(S) URL without credentials, or '-' to skip."
            )
            return step
    elif step == TASK_REPLACE_SAMPLE:
        answer = answer.lower()
        if answer not in {"yes", "no"}:
            await update.effective_message.reply_text("Please answer `yes` or `no`.")
            return step

    key_by_step = {
        TASK_ID: "id",
        TASK_NAME: "task",
        TASK_EMPLOYEE: "employee",
        TASK_USERNAME: "username",
        TASK_URL: "url",
        TASK_REPLACE_SAMPLE: "replace_sample",
        TASK_DESCRIPTION: "description",
    }
    field_key = key_by_step[step]
    if answer != "-" or step not in {TASK_USERNAME, TASK_URL}:
        fields[field_key] = answer

    next_step_index = TASK_ASSIGNMENT_STEPS.index(step) + 1
    if next_step_index < len(TASK_ASSIGNMENT_STEPS):
        next_step = TASK_ASSIGNMENT_STEPS[next_step_index]
        context.user_data[f"{state_key}:step"] = next_step
        await update.effective_message.reply_text(TASK_ASSIGNMENT_PROMPTS[next_step])
        return next_step

    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "assign_task",
        "--id",
        fields["id"],
        "--task",
        fields["task"],
        "--employee",
        fields["employee"],
        "--description",
        fields["description"],
    ]
    if fields.get("username"):
        command.extend(["--username", fields["username"]])
    if fields.get("url"):
        command.extend(["--url", fields["url"]])
    if fields.get("replace_sample") == "yes":
        command.append("--replace-demo")

    state_key = task_assignment_key(update)
    context.user_data.pop(state_key, None)
    context.user_data.pop(f"{state_key}:step", None)
    await run_task_update(update, command, fields["id"], "assign")
    return ConversationHandler.END


async def cancel_task_assign(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    state_key = task_assignment_key(update)
    if state_key not in context.user_data:
        await update.effective_message.reply_text("No task assignment is in progress.")
        return ConversationHandler.END
    context.user_data.pop(state_key, None)
    context.user_data.pop(f"{state_key}:step", None)
    await update.effective_message.reply_text("Task assignment cancelled.")
    return ConversationHandler.END


async def report(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        await update.effective_message.reply_text(
            "You are not authorized to report tasks in this chat."
        )
        return

    try:
        fields = parse_report(update.effective_message.text)
        command = [
            sys.executable,
            str(Path(__file__).with_name("update_tasks.py")),
            "report",
            "--id",
            fields["id"],
            "--description",
            fields["description"],
        ]
    except ValueError as error:
        await update.effective_message.reply_text(f"Invalid task report: {error}")
        return
    await run_task_update(update, command, fields["id"], "report")


async def carry(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not authorized(
        update,
        context.bot_data["task_assign_user_ids"],
        context.bot_data["allowed_chat_ids"],
    ):
        await update.effective_message.reply_text(
            "You are not authorized to carry tasks in this chat."
        )
        return

    try:
        fields = parse_carry(update.effective_message.text)
        command = [
            sys.executable,
            str(Path(__file__).with_name("update_tasks.py")),
            "carry",
            "--id",
            fields["id"],
            "--from-date",
            fields["from date"],
        ]
    except ValueError as error:
        await update.effective_message.reply_text(f"Invalid task carry: {error}")
        return
    await run_task_update(update, command, fields["id"], "carry")


def format_task_list(data: dict) -> str:
    tasks = data["tasks"]
    header = f"Task list for {data['date']} ({len(tasks)} task(s))"
    if not tasks:
        return f"{header}\nNo tasks assigned."

    entries = []
    for task in tasks:
        report_data = task.get("employee_report")
        report_text = (
            report_data.get("description", "").strip()
            if isinstance(report_data, dict)
            else ""
        )
        entries.append(
            "\n".join(
                [
                    f"ID: {task['id']}",
                    f"Task: {task['repo']['name']}",
                    f"Employee: {task['assigned_to']['name']}",
                    f"Description: {task['description']}",
                    f"Report: {report_text or 'Awaiting employee report.'}",
                ]
            )
        )
    return f"{header}\n\n" + "\n\n".join(entries)


def split_message(text: str, limit: int = 3500) -> list[str]:
    chunks = []
    while len(text) > limit:
        split_at = text.rfind("\n", 0, limit + 1)
        if split_at <= 0:
            split_at = limit
        chunks.append(text[:split_at])
        text = text[split_at:].lstrip("\n")
    if text:
        chunks.append(text)
    return chunks


async def task_lists(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        await update.effective_message.reply_text(
            "You are not authorized to view task lists in this chat."
        )
        return

    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "list",
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip()
            logging.error("Could not load task list: %s", detail)
            await update.effective_message.reply_text(f"Could not load task list: {detail}")
            return
        data = json.loads(result.stdout)
        if not isinstance(data, dict) or not isinstance(data.get("tasks"), list):
            raise ValueError("Invalid daily task list format.")
        messages = split_message(format_task_list(data))
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        logging.exception("Could not format today's task list.")
        await update.effective_message.reply_text(f"Could not load task list: {error}")
        return

    for message in messages:
        await update.effective_message.reply_text(message)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        await update.effective_message.reply_text("This user or chat is not authorized.")
        return
    role = (
        "You can assign tasks."
        if update.effective_user.id in context.bot_data["task_assign_user_ids"]
        else "You can use the bot, but cannot assign tasks."
    )
    await update.effective_message.reply_text(
        f"Employee Tasks bot is running. {role} Use /whoami to view your Telegram IDs."
    )


async def whoami(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    user = update.effective_user
    chat = update.effective_chat
    if user is None or chat is None:
        return
    await update.effective_message.reply_text(f"Telegram user ID: {user.id}\nChat ID: {chat.id}")


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    try:
        token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
        if not token:
            raise ValueError("TELEGRAM_BOT_TOKEN is required.")
        task_assign_user_ids = allowed_ids(
            "TELEGRAM_TASK_ASSIGN_USER_IDS", positive_only=True
        )
        standard_user_ids = allowed_ids(
            "TELEGRAM_STANDARD_USER_IDS", positive_only=True
        )
        chat_ids = allowed_ids("TELEGRAM_ALLOWED_CHAT_IDS")
    except ValueError as error:
        raise SystemExit(f"Telegram bot configuration error: {error}") from error

    if not (task_assign_user_ids or standard_user_ids) or not chat_ids:
        logging.warning(
            "User or chat allowlist is empty; authorized bot commands will be denied."
        )

    application = Application.builder().token(token).build()
    application.bot_data["task_assign_user_ids"] = task_assign_user_ids
    application.bot_data["standard_user_ids"] = standard_user_ids
    application.bot_data["allowed_chat_ids"] = chat_ids
    task_assign_conversation = ConversationHandler(
        entry_points=[CommandHandler("task_assign", task_assign_start)],
        states={
            step: [MessageHandler(filters.TEXT & ~filters.COMMAND, task_assign_answer)]
            for step in TASK_ASSIGNMENT_STEPS
        },
        fallbacks=[CommandHandler("cancel", cancel_task_assign)],
        per_chat=True,
        per_user=True,
    )
    application.add_handler(task_assign_conversation)
    application.add_handler(CommandHandler("cancel", cancel_task_assign))
    application.add_handler(CommandHandler("task_lists", task_lists))
    application.add_handler(CommandHandler("report", report))
    application.add_handler(CommandHandler("carry", carry))
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("whoami", whoami))
    application.run_polling()


if __name__ == "__main__":
    main()
