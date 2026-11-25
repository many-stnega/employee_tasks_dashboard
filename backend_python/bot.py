#!/usr/bin/env python3
"""Telegram bot entry point for the employee tasks dashboard."""
import logging
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid
from datetime import datetime, timedelta, timezone

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.error import TelegramError
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
    ConversationHandler,
    MessageHandler,
    filters,
)

TASK_NAME, TASK_EMPLOYEE, TASK_DESCRIPTION = range(3)
REPORT_TASK, REPORT_DESCRIPTION = range(7, 9)
TASK_ASSIGNMENT_STEPS = (
    TASK_NAME,
    TASK_EMPLOYEE,
    TASK_DESCRIPTION,
)
TASK_ASSIGNMENT_PROMPTS = {
    TASK_NAME: "What is the task name?",
    TASK_DESCRIPTION: "Describe the task. You can include multiple lines:",
}


def task_name(task: dict) -> str:
    return task.get("task") or task.get("repo", {}).get("name", "Untitled task")


def task_username(task: dict) -> str:
    assigned_to = task.get("assigned_to", {})
    if isinstance(assigned_to, dict):
        return assigned_to.get("username") or assigned_to.get("name", "Unknown")
    return str(assigned_to)


def task_assignment_key(update: Update) -> str:
    return f"task_assignment:{update.effective_chat.id}"


def report_key(update: Update) -> str:
    return f"task_report:{update.effective_chat.id}"


def today_key() -> str:
    return datetime.now(timezone(timedelta(hours=6, minutes=30))).strftime("%Y%m%d")


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
) -> bool:
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        logging.exception("Could not run task %s command.", action)
        await update.effective_message.reply_text(f"Could not {action} task: {error}")
        return False
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        logging.error("Could not %s task: %s", action, detail)
        await update.effective_message.reply_text(f"Could not {action} task: {detail}")
        return False
    if action == "carry" and "already exists" in result.stdout.lower():
        await update.effective_message.reply_text(result.stdout.strip())
        return False
    past_tense = {"assign": "assigned", "report": "reported", "carry": "carried"}
    await update.effective_message.reply_text(f"Task {past_tense[action]}: {task_id}.")
    return True


def telegram_message_chunks(text: str, limit: int = 4000) -> list[str]:
    chunks = []
    while len(text) > limit:
        split_at = text.rfind("\n", 0, limit)
        if split_at <= 0:
            split_at = limit
        chunks.append(text[:split_at])
        text = text[split_at:].lstrip("\n")
    if text:
        chunks.append(text)
    return chunks


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
    context.user_data[state_key] = {"id": f"task-{today_key()}-{uuid.uuid4().hex[:8]}"}
    context.user_data[f"{state_key}:step"] = TASK_NAME
    await update.effective_message.reply_text(TASK_ASSIGNMENT_PROMPTS[TASK_NAME])
    return TASK_NAME


async def employee_keyboard(context: ContextTypes.DEFAULT_TYPE) -> tuple[list[dict], InlineKeyboardMarkup]:
    employees = []
    buttons = []
    for user_id in sorted(context.bot_data["standard_user_ids"]):
        try:
            chat = await context.bot.get_chat(user_id)
        except TelegramError as error:
            logging.warning(
                "Could not retrieve Telegram profile for allowed user %s: %s",
                user_id,
                error,
            )
            continue

        username = getattr(chat, "username", None)
        if not username:
            logging.warning(
                "Allowed Telegram user %s has no username and cannot be assigned.",
                user_id,
            )
            continue
        employee = {"id": user_id, "username": username}
        employees.append(employee)
        buttons.append(
            InlineKeyboardButton(f"@{username}"[:64], callback_data=f"assign_employee:{user_id}")
        )

    if not buttons:
        raise ValueError(
            "No assignable Telegram usernames were found in TELEGRAM_STANDARD_USER_IDS. "
            "Make sure each employee has a Telegram username and has started the bot."
        )

    rows = [buttons[index:index + 2] for index in range(0, len(buttons), 2)]
    return employees, InlineKeyboardMarkup(rows)


async def select_task_employee(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    query = update.callback_query
    await query.answer()
    if not authorized(
        update,
        context.bot_data["task_assign_user_ids"],
        context.bot_data["allowed_chat_ids"],
    ):
        await query.edit_message_text("You are not authorized to assign tasks in this chat.")
        return ConversationHandler.END

    state_key = task_assignment_key(update)
    fields = context.user_data.get(state_key)
    employees = context.user_data.get(f"{state_key}:employees", [])
    try:
        selected_id = int(query.data.partition(":")[2])
    except ValueError:
        selected_id = None
    selected = next((employee for employee in employees if employee["id"] == selected_id), None)
    if not fields or selected is None:
        await query.edit_message_text("Employee selection expired. Send /task_assign to try again.")
        return ConversationHandler.END

    fields["username"] = selected["username"]
    fields["employee_id"] = selected["id"]
    context.user_data.pop(f"{state_key}:employees", None)
    context.user_data[f"{state_key}:step"] = TASK_DESCRIPTION
    await query.edit_message_text(
        f"Assigned to @{selected['username']}.\n{TASK_ASSIGNMENT_PROMPTS[TASK_DESCRIPTION]}"
    )
    return TASK_DESCRIPTION


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
    if step == TASK_NAME:
        fields["task"] = answer
        try:
            employees, keyboard = await employee_keyboard(context)
        except ValueError as error:
            await update.effective_message.reply_text(str(error))
            context.user_data.pop(state_key, None)
            context.user_data.pop(f"{state_key}:step", None)
            return ConversationHandler.END
        context.user_data[f"{state_key}:employees"] = employees
        context.user_data[f"{state_key}:step"] = TASK_EMPLOYEE
        await update.effective_message.reply_text(
            "Choose an employee by Telegram username:",
            reply_markup=keyboard,
        )
        return TASK_EMPLOYEE

    fields["description"] = answer

    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "assign_task",
        "--id",
        fields["id"],
        "--task",
        fields["task"],
        "--username",
        fields["username"],
        "--description",
        fields["description"],
    ]

    state_key = task_assignment_key(update)
    context.user_data.pop(state_key, None)
    context.user_data.pop(f"{state_key}:step", None)
    saved = await run_task_update(update, command, fields["id"], "assign")
    if saved:
        recipient_id = fields["employee_id"]
        assignment_message = "\n".join(
            [
                "📌 New task assigned",
                "",
                f"📝 {fields['task']}",
                "",
                "Description",
                fields["description"],
            ]
        )
        try:
            for message in telegram_message_chunks(assignment_message):
                await context.bot.send_message(chat_id=recipient_id, text=message)
        except TelegramError as error:
            logging.warning(
                "Task %s was saved but could not be sent to Telegram user %s: %s",
                fields["id"],
                recipient_id,
                error,
            )
            await update.effective_message.reply_text(
                f"Task {fields['id']} was saved, but Telegram could not deliver it "
                f"directly to @{fields['username']} (ID: {recipient_id}). "
                "Ask them to open the bot and send /start, then share this saved "
                "task with them manually. Future assignments can be delivered directly."
            )
        else:
            await update.effective_message.reply_text(
                f"Task {fields['id']} was sent directly to @{fields['username']}."
            )
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


async def report_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        await update.effective_message.reply_text(
            "You are not authorized to report tasks in this chat."
        )
        return ConversationHandler.END

    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "list",
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip()
            logging.error("Could not load tasks for report: %s", detail)
            await update.effective_message.reply_text(f"Could not load tasks: {detail}")
            return ConversationHandler.END
        data = json.loads(result.stdout)
        tasks = data.get("tasks") if isinstance(data, dict) else None
        if not isinstance(tasks, list):
            raise ValueError("Invalid daily task list format.")
        if not tasks:
            await update.effective_message.reply_text("There are no tasks to report today.")
            return ConversationHandler.END
        context.user_data[report_key(update)] = tasks
        buttons = [
            InlineKeyboardButton(
                f"📝 {task_name(task)} · @{task_username(task)}"[:64],
                callback_data=f"report_task:{index}",
            )
            for index, task in enumerate(tasks)
        ]
        keyboard = InlineKeyboardMarkup(
            [[button] for button in buttons]
        )
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        logging.exception("Could not prepare report task selection.")
        await update.effective_message.reply_text(f"Could not load tasks: {error}")
        return ConversationHandler.END

    await update.effective_message.reply_text(
        f"📝 Choose a task to report\n{data['date']}\n\nTap a task below, or send /cancel.",
        reply_markup=keyboard,
    )
    return REPORT_TASK


async def report_select_task(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(report_key(update), None)
        await query.edit_message_text(
            "You are not authorized to report tasks in this chat."
        )
        return ConversationHandler.END
    tasks = context.user_data.get(report_key(update))
    if not tasks:
        await query.edit_message_text("Task selection expired. Send /report to try again.")
        return ConversationHandler.END
    try:
        selection = int(query.data.partition(":")[2])
        if not 0 <= selection < len(tasks):
            raise ValueError
    except ValueError:
        await query.edit_message_text(
            "That task selection is invalid. Send /report to choose again."
        )
        return ConversationHandler.END

    selected_task = tasks[selection]
    context.user_data[report_key(update)] = selected_task
    await query.edit_message_text(
        f"📝 {task_name(selected_task)}\n"
        f"Engineer: @{task_username(selected_task)}\n\n"
        "Send the report below. New reports will be added after previous reports."
    )
    return REPORT_DESCRIPTION


async def report_save(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(report_key(update), None)
        await update.effective_message.reply_text(
            "You are not authorized to report tasks in this chat."
        )
        return ConversationHandler.END
    task = context.user_data.get(report_key(update))
    if not isinstance(task, dict):
        await update.effective_message.reply_text("Task selection expired. Send /report to try again.")
        return ConversationHandler.END

    description = update.effective_message.text.strip()
    if not description:
        await update.effective_message.reply_text("Report cannot be empty. Please enter the report.")
        return REPORT_DESCRIPTION

    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "report",
        "--id",
        task["id"],
        "--description",
        description,
    ]
    context.user_data.pop(report_key(update), None)
    await run_task_update(update, command, task["id"], "report")
    return ConversationHandler.END


async def cancel_report(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.pop(report_key(update), None)
    await update.effective_message.reply_text("Report cancelled.")
    return ConversationHandler.END


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
                    f"Task: {task_name(task)}",
                    f"Engineer: @{task_username(task)}",
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
            **{
                step: [MessageHandler(filters.TEXT & ~filters.COMMAND, task_assign_answer)]
                for step in TASK_ASSIGNMENT_STEPS
                if step != TASK_EMPLOYEE
            },
            TASK_EMPLOYEE: [CallbackQueryHandler(select_task_employee, pattern=r"^assign_employee:\d+$")],
        },
        fallbacks=[CommandHandler("cancel", cancel_task_assign)],
        per_chat=True,
        per_user=True,
    )
    report_conversation = ConversationHandler(
        entry_points=[CommandHandler("report", report_start)],
        states={
            REPORT_TASK: [CallbackQueryHandler(report_select_task, pattern=r"^report_task:\d+$")],
            REPORT_DESCRIPTION: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, report_save)
            ],
        },
        fallbacks=[CommandHandler("cancel", cancel_report)],
        per_chat=True,
        per_user=True,
    )
    application.add_handler(task_assign_conversation)
    application.add_handler(report_conversation)
    application.add_handler(CommandHandler("cancel", cancel_task_assign))
    application.add_handler(CommandHandler("task_lists", task_lists))
    application.add_handler(CommandHandler("carry", carry))
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("whoami", whoami))
    application.run_polling()


if __name__ == "__main__":
    main()
