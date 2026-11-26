#!/usr/bin/env python3
"""Telegram bot entry point for the employee tasks dashboard."""
import asyncio
import logging
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone

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
TASK_LIST_SELECT, TASK_LIST_REPORT_DESCRIPTION = range(9, 11)
END_TASK_SELECT = 11
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


def task_reports(task: dict) -> list[dict]:
    reports = task.get("employee_reports")
    if isinstance(reports, list):
        return reports
    legacy_report = task.get("employee_report")
    return [legacy_report] if isinstance(legacy_report, dict) else []


def task_assignment_key(update: Update) -> str:
    return f"task_assignment:{update.effective_chat.id}"


def report_key(update: Update) -> str:
    return f"task_report:{update.effective_chat.id}"


def task_list_key(update: Update) -> str:
    return f"task_list:{update.effective_chat.id}"


def end_task_key(update: Update) -> str:
    return f"end_task:{update.effective_chat.id}"


def data_directory() -> Path:
    return Path(
        os.environ.get(
            "TASKS_DATA_DIR",
            Path(__file__).resolve().parents[1] / "json_data_records",
        )
    )


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
    task_id: str | None,
    action: str,
) -> str | bool:
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
    if task_id is None:
        task_id = result.stdout.strip().split(':', 1)[0].removeprefix('Saved ')
    past_tense = {
        "assign": "assigned",
        "report": "reported",
        "carry": "carried",
        "end": "completed",
    }
    await update.effective_message.reply_text(f"Task {past_tense[action]}: {task_id}.")
    return task_id


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
    context.user_data[state_key] = {}
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
    saved = await run_task_update(update, command, None, "assign")
    if saved:
        fields["id"] = saved
        recipient_id = fields["employee_id"]
        assignment_message = "\n".join(
            [
                "📌 New task assigned",
                f"Task ID: {fields['id']}",
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
    if await run_task_update(update, command, task["id"], "report"):
        await notify_report_received(update, context, task, description)
    return ConversationHandler.END


async def notify_report_received(
    update: Update, context: ContextTypes.DEFAULT_TYPE, task: dict, description: str
) -> None:
    user = update.effective_user
    reporter = f"@{user.username}" if user.username else str(user.id)
    message = "\n".join([
        "📝 Task report received",
        f"Task ID: {task['id']}",
        f"Task: {task_name(task)}",
        f"Assigned to: @{task_username(task).lstrip('@')}",
        f"Reported by: {reporter}",
        "", description,
    ])
    failed = 0
    for chat_id in sorted(context.bot_data.get("report_received_chat_ids", set())):
        try:
            for chunk in telegram_message_chunks(message):
                await context.bot.send_message(chat_id=chat_id, text=chunk)
        except TelegramError:
            failed += 1
            logging.exception("Report for task %s could not be sent to chat %s.", task['id'], chat_id)
    if failed:
        await update.effective_message.reply_text(
            f"Report saved, but notification delivery failed for {failed} chat(s)."
        )


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


def task_list_selection_keyboard(tasks: list[dict]) -> InlineKeyboardMarkup:
    buttons = [
        [InlineKeyboardButton(task_name(task)[:64], callback_data=f"task_list:{index}")]
        for index, task in enumerate(tasks)
    ]
    return InlineKeyboardMarkup(buttons)


def task_detail_text(task: dict, date: str) -> str:
    reports = task_reports(task)
    report_lines = []
    for report in reports:
        reported_at = datetime.fromisoformat(
            report["reported_at"].replace("Z", "+00:00")
        ).astimezone(timezone(timedelta(hours=6, minutes=30)))
        report_lines.append(
            f"🕒 {reported_at.strftime('%Y-%m-%d %I:%M %p')} MMT\n"
            f"{report['description']}"
        )
    report_text = "\n\n".join(report_lines) if report_lines else "No reports yet."
    return "\n".join(
        [
            f"📋 {task_name(task)}",
            f"Task ID: {task['id']}",
            f"📅 {date}",
            f"👷 Engineer: @{task_username(task)}",
            f"Status: {'✅ Completed' if task.get('status') == 'completed' else '🟡 In progress'}",
            "",
            "Description",
            task["description"],
            "",
            f"Reports ({len(reports)})",
            report_text,
        ]
    )


def task_detail_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("📝 Add report", callback_data="task_list_report")],
            [InlineKeyboardButton("← Back to tasks", callback_data="task_list_back")],
        ]
    )


async def load_today_task_data() -> dict:
    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "list",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"Could not load task list: {detail}")
    data = json.loads(result.stdout)
    if not isinstance(data, dict) or not isinstance(data.get("tasks"), list):
        raise ValueError("Invalid daily task list format.")
    return data


async def task_lists(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        await update.effective_message.reply_text(
            "You are not authorized to view task lists in this chat."
        )
        return ConversationHandler.END
    try:
        data = await load_today_task_data()
        tasks = data["tasks"]
        if not tasks:
            await update.effective_message.reply_text("There are no tasks for today.")
            return ConversationHandler.END
        context.user_data[task_list_key(update)] = data
    except (OSError, RuntimeError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        logging.exception("Could not load today's task list.")
        await update.effective_message.reply_text(f"Could not load task list: {error}")
        return ConversationHandler.END
    await update.effective_message.reply_text(
        f"📋 Today's tasks · {data['date']}\nChoose a task:",
        reply_markup=task_list_selection_keyboard(tasks),
    )
    return TASK_LIST_SELECT


async def task_list_select(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(task_list_key(update), None)
        await query.edit_message_text("You are not authorized to view task lists in this chat.")
        return ConversationHandler.END
    data = context.user_data.get(task_list_key(update))
    if not isinstance(data, dict):
        await query.edit_message_text("Task list expired. Send /task_lists to try again.")
        return ConversationHandler.END
    try:
        index = int(query.data.partition(":")[2])
        task = data["tasks"][index]
    except (IndexError, TypeError, ValueError):
        await query.edit_message_text("That task selection is invalid. Send /task_lists to try again.")
        return ConversationHandler.END
    context.user_data[f"{task_list_key(update)}:selected"] = index
    await query.edit_message_text(
        task_detail_text(task, data["date"]),
        reply_markup=task_detail_keyboard(),
    )
    return TASK_LIST_SELECT


async def task_list_back(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(task_list_key(update), None)
        await query.edit_message_text("You are not authorized to view task lists in this chat.")
        return ConversationHandler.END
    data = context.user_data.get(task_list_key(update))
    if not isinstance(data, dict):
        await query.edit_message_text("Task list expired. Send /task_lists to try again.")
        return ConversationHandler.END
    await query.edit_message_text(
        f"📋 Today's tasks · {data['date']}\nChoose a task:",
        reply_markup=task_list_selection_keyboard(data["tasks"]),
    )
    return TASK_LIST_SELECT


async def task_list_report_start(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    query = update.callback_query
    await query.answer()
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        await query.edit_message_text("You are not authorized to report tasks in this chat.")
        return ConversationHandler.END
    data = context.user_data.get(task_list_key(update))
    index = context.user_data.get(f"{task_list_key(update)}:selected")
    if not isinstance(data, dict) or not isinstance(index, int):
        await query.edit_message_text("Task selection expired. Send /task_lists to try again.")
        return ConversationHandler.END
    try:
        task = data["tasks"][index]
    except IndexError:
        await query.edit_message_text("Task selection expired. Send /task_lists to try again.")
        return ConversationHandler.END
    context.user_data[f"{task_list_key(update)}:report_task"] = task
    await query.edit_message_text(
        f"📝 Report for {task_name(task)}\n\n"
        "Send your report as a message. It will be added to the report history."
    )
    return TASK_LIST_REPORT_DESCRIPTION


async def task_list_report_save(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> int:
    allowed_user_ids = (
        context.bot_data["task_assign_user_ids"]
        | context.bot_data["standard_user_ids"]
    )
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(task_list_key(update), None)
        await update.effective_message.reply_text("You are not authorized to report tasks in this chat.")
        return ConversationHandler.END
    task = context.user_data.get(f"{task_list_key(update)}:report_task")
    if not isinstance(task, dict):
        await update.effective_message.reply_text("Task selection expired. Send /task_lists to try again.")
        return ConversationHandler.END
    description = update.effective_message.text.strip()
    if not description:
        await update.effective_message.reply_text("Report cannot be empty. Please enter the report.")
        return TASK_LIST_REPORT_DESCRIPTION
    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "report",
        "--id",
        task["id"],
        "--description",
        description,
    ]
    saved = await run_task_update(update, command, task["id"], "report")
    if saved:
        await notify_report_received(update, context, task, description)
        try:
            data = await load_today_task_data()
            task_list = context.user_data.get(task_list_key(update))
            if isinstance(task_list, dict):
                task_list["tasks"] = data["tasks"]
                selected_index = context.user_data.get(f"{task_list_key(update)}:selected")
                if isinstance(selected_index, int) and selected_index < len(data["tasks"]):
                    await update.effective_message.reply_text(
                        task_detail_text(data["tasks"][selected_index], data["date"]),
                        reply_markup=task_detail_keyboard(),
                    )
        except (OSError, RuntimeError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
            logging.exception("Could not reload task details after report.")
            await update.effective_message.reply_text(f"Report saved, but could not reload task details: {error}")
    context.user_data.pop(f"{task_list_key(update)}:report_task", None)
    return ConversationHandler.END


async def cancel_task_list(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.pop(task_list_key(update), None)
    context.user_data.pop(f"{task_list_key(update)}:selected", None)
    context.user_data.pop(f"{task_list_key(update)}:report_task", None)
    await update.effective_message.reply_text("Task list closed.")
    return ConversationHandler.END


async def cancel_end_task(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    context.user_data.pop(end_task_key(update), None)
    await update.effective_message.reply_text("Task completion cancelled.")
    return ConversationHandler.END


async def end_task_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    allowed_user_ids = context.bot_data["task_assign_user_ids"]
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(end_task_key(update), None)
        await update.effective_message.reply_text(
            "You are not authorized to end tasks in this chat."
        )
        return ConversationHandler.END
    try:
        data = await load_today_task_data()
    except (OSError, RuntimeError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        logging.exception("Could not load tasks to end.")
        await update.effective_message.reply_text(f"Could not load tasks: {error}")
        return ConversationHandler.END

    tasks = [
        task for task in data["tasks"]
        if task.get("status") != "completed"
    ]
    if not tasks:
        await update.effective_message.reply_text(
            "There are no unfinished tasks available for you to end."
        )
        return ConversationHandler.END
    context.user_data[end_task_key(update)] = {
        "date": data["date"],
        "tasks": tasks,
    }
    keyboard = InlineKeyboardMarkup(
        [
            [InlineKeyboardButton(task_name(task)[:64], callback_data=f"end_task:{index}")]
            for index, task in enumerate(tasks)
        ]
    )
    await update.effective_message.reply_text(
        "✅ Choose the task you have finished:",
        reply_markup=keyboard,
    )
    return END_TASK_SELECT


async def end_task_select(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    query = update.callback_query
    await query.answer()
    allowed_user_ids = context.bot_data["task_assign_user_ids"]
    if not authorized(update, allowed_user_ids, context.bot_data["allowed_chat_ids"]):
        context.user_data.pop(end_task_key(update), None)
        await query.edit_message_text("You are not authorized to end tasks in this chat.")
        return ConversationHandler.END
    selection = context.user_data.get(end_task_key(update))
    if not isinstance(selection, dict):
        await query.edit_message_text("Task selection expired. Send /end_task to try again.")
        return ConversationHandler.END
    try:
        index = int(query.data.partition(":")[2])
        task = selection["tasks"][index]
    except (IndexError, TypeError, ValueError):
        await query.edit_message_text("Invalid task selection. Send /end_task to try again.")
        return ConversationHandler.END
    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "end_task",
        "--id",
        task["id"],
    ]
    context.user_data.pop(end_task_key(update), None)
    if await run_task_update(update, command, task["id"], "end"):
        await update.effective_message.reply_text(
            "✅ Task completed. It will no longer be carried forward."
        )
    return ConversationHandler.END


async def auto_carry_forward(target_date: str) -> None:
    folder = data_directory()
    source_dates = []
    for path in folder.glob("*.json"):
        try:
            source_date = date.fromisoformat(path.stem)
        except ValueError:
            continue
        if source_date.isoformat() >= target_date:
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise RuntimeError(f"Could not inspect task file {path}: {error}") from error
        if (
            not isinstance(data, dict)
            or data.get("date") != source_date.isoformat()
            or not isinstance(data.get("tasks"), list)
        ):
            raise RuntimeError(f"Invalid daily task file for rollover: {path}")
        if data.get("demo") is not True:
            source_dates.append(source_date.isoformat())
    if not source_dates:
        logging.info("No earlier task records found to carry into %s.", target_date)
        return

    command = [
        sys.executable,
        str(Path(__file__).with_name("update_tasks.py")),
        "--date",
        target_date,
        "carry_forward",
        "--from-date",
        max(source_dates),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"Automatic carry-forward failed: {detail}")
    logging.info(result.stdout.strip())


async def task_rollover_loop() -> None:
    mmt = timezone(timedelta(hours=6, minutes=30))
    while True:
        now = datetime.now(mmt)
        try:
            await auto_carry_forward(now.date().isoformat())
        except (OSError, RuntimeError) as error:
            logging.exception("Could not carry unfinished tasks forward.")
            wait_seconds = 60
        else:
            tomorrow = now.date() + timedelta(days=1)
            next_midnight = datetime.combine(tomorrow, datetime.min.time(), tzinfo=mmt)
            wait_seconds = max(1, (next_midnight - datetime.now(mmt)).total_seconds())
        await asyncio.sleep(wait_seconds)


async def application_post_init(application: Application) -> None:
    application.bot_data["task_rollover_job"] = asyncio.create_task(task_rollover_loop())


async def application_post_shutdown(application: Application) -> None:
    job = application.bot_data.get("task_rollover_job")
    if job is not None:
        job.cancel()
        try:
            await job
        except asyncio.CancelledError:
            pass


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
        report_received_chat_ids = allowed_ids("TELEGRAM_REPORT_RECEIVED_CHAT_IDS")
    except ValueError as error:
        raise SystemExit(f"Telegram bot configuration error: {error}") from error

    if not (task_assign_user_ids or standard_user_ids) or not chat_ids:
        logging.warning(
            "User or chat allowlist is empty; authorized bot commands will be denied."
        )

    application = (
        Application.builder()
        .token(token)
        .post_init(application_post_init)
        .post_shutdown(application_post_shutdown)
        .build()
    )
    application.bot_data["task_assign_user_ids"] = task_assign_user_ids
    application.bot_data["standard_user_ids"] = standard_user_ids
    application.bot_data["allowed_chat_ids"] = chat_ids
    application.bot_data["report_received_chat_ids"] = report_received_chat_ids
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
    task_list_conversation = ConversationHandler(
        entry_points=[CommandHandler("task_lists", task_lists)],
        states={
            TASK_LIST_SELECT: [
                CallbackQueryHandler(task_list_select, pattern=r"^task_list:\d+$"),
                CallbackQueryHandler(task_list_report_start, pattern=r"^task_list_report$"),
                CallbackQueryHandler(task_list_back, pattern=r"^task_list_back$"),
            ],
            TASK_LIST_REPORT_DESCRIPTION: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, task_list_report_save)
            ],
        },
        fallbacks=[CommandHandler("cancel", cancel_end_task)],
        per_chat=True,
        per_user=True,
    )
    end_task_conversation = ConversationHandler(
        entry_points=[CommandHandler("end_task", end_task_start)],
        states={
            END_TASK_SELECT: [
                CallbackQueryHandler(end_task_select, pattern=r"^end_task:\d+$")
            ],
        },
        fallbacks=[CommandHandler("cancel", cancel_task_list)],
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
    application.add_handler(task_list_conversation)
    application.add_handler(end_task_conversation)
    application.add_handler(report_conversation)
    application.add_handler(CommandHandler("cancel", cancel_task_assign))
    application.add_handler(CommandHandler("carry", carry))
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("whoami", whoami))
    application.run_polling()


if __name__ == "__main__":
    main()
