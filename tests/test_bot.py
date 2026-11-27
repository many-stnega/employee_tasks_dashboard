import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from telegram.ext import ConversationHandler
from telegram.error import TelegramError

from backend_python import bot


class EndTaskAuthorizationTests(unittest.IsolatedAsyncioTestCase):
    def make_request(self, user_id=1, chat_id=-100, managers=None):
        update = SimpleNamespace(
            effective_user=SimpleNamespace(id=user_id, username="employee", full_name="Report Writer"),
            effective_chat=SimpleNamespace(id=chat_id),
            effective_message=SimpleNamespace(reply_text=AsyncMock()),
            callback_query=SimpleNamespace(
                answer=AsyncMock(), edit_message_text=AsyncMock(), data="end_task:0"
            ),
        )
        context = SimpleNamespace(
            bot_data={
                "task_assign_user_ids": {1} if managers is None else managers,
                "standard_user_ids": {2},
                "allowed_chat_ids": {-100},
            },
            user_data={},
        )
        return update, context

    async def test_denied_users_and_chats_cannot_start_or_use_saved_selection(self):
        for user_id, chat_id, managers in (
            (2, -100, {1}),  # Standard user, including their own task.
            (3, -100, {1}),  # Unknown user.
            (1, -200, {1}),  # Manager in an unapproved chat.
            (1, -100, set()),  # Empty allowlist or revoked manager access.
        ):
            for handler in (bot.end_task_start, bot.end_task_select):
                with self.subTest(user=user_id, chat=chat_id, handler=handler.__name__):
                    update, context = self.make_request(user_id, chat_id, managers)
                    key = bot.end_task_key(update)
                    context.user_data[key] = {
                        "tasks": [{"id": "task-1", "assigned_to": {"username": "employee"}}]
                    }
                    with patch.object(bot, "load_today_task_data", new_callable=AsyncMock) as load, patch.object(
                        bot, "run_task_update", new_callable=AsyncMock
                    ) as save:
                        self.assertEqual(await handler(update, context), ConversationHandler.END)
                        load.assert_not_awaited()
                        save.assert_not_awaited()
                    self.assertNotIn(key, context.user_data)

    async def test_manager_can_select_and_complete_another_employees_task(self):
        update, context = self.make_request()
        task = {"id": "task-1", "task": "Review", "assigned_to": {"username": "other"}}
        data = {"date": "2026-11-26", "tasks": [task, {"id": "done", "status": "completed"}]}
        with patch.object(bot, "load_today_task_data", new_callable=AsyncMock, return_value=data):
            self.assertEqual(await bot.end_task_start(update, context), bot.END_TASK_SELECT)
        self.assertEqual(context.user_data[bot.end_task_key(update)]["tasks"], [task])
        with patch.object(bot, "run_task_update", new_callable=AsyncMock, return_value=True) as save:
            self.assertEqual(await bot.end_task_select(update, context), ConversationHandler.END)
            save.assert_awaited_once()
            self.assertEqual(save.call_args.args[1][-3:], ["end_task", "--id", "task-1"])
        self.assertNotIn(bot.end_task_key(update), context.user_data)


class ReportNotificationTests(unittest.IsolatedAsyncioTestCase):
    async def test_both_report_paths_notify_only_after_successful_save(self):
        for handler in (bot.report_save, bot.task_list_report_save):
            for saved in (False, "1"):
                with self.subTest(handler=handler.__name__, saved=saved):
                    update, context = EndTaskAuthorizationTests().make_request(user_id=2)
                    update.effective_message.text = "Finished testing"
                    task = {"id": "1", "task": "Testing", "assigned_to": {"username": "employee"}}
                    context.user_data[bot.report_key(update)] = task
                    context.user_data[f"{bot.task_list_key(update)}:report_task"] = task
                    context.bot_data["report_received_chat_ids"] = {11, -200}
                    context.bot = SimpleNamespace(send_message=AsyncMock())
                    with patch.object(bot, "run_task_update", new_callable=AsyncMock, return_value=saved) as save, patch.object(
                        bot, "load_today_task_data", new_callable=AsyncMock, return_value={"tasks": [task]}
                    ):
                        await handler(update, context)
                    command = save.call_args.args[1]
                    self.assertEqual(command[command.index("--reporter-id") + 1], "2")
                    self.assertEqual(command[command.index("--reporter-name") + 1], "Report Writer")
                    self.assertEqual(command[command.index("--reporter-username") + 1], "employee")
                    calls = context.bot.send_message.await_args_list
                    self.assertEqual({call.kwargs['chat_id'] for call in calls}, {11, -200} if saved else set())
                    for call in calls:
                        self.assertIn("Task ID: 1", call.kwargs['text'])
                        self.assertIn("Reported by: @employee", call.kwargs['text'])
                        self.assertIn("Finished testing", call.kwargs['text'])

    async def test_delivery_failure_does_not_stop_other_recipients(self):
        update, context = EndTaskAuthorizationTests().make_request()
        context.bot_data["report_received_chat_ids"] = {-200, 11}
        async def send_message(chat_id, text):
            if chat_id == -200:
                raise TelegramError("blocked")
        context.bot = SimpleNamespace(send_message=AsyncMock(side_effect=send_message))
        with self.assertLogs(level="ERROR"):
            await bot.notify_report_received(update, context, {"id": "1", "task": "Testing"}, "x" * 5000)
        calls = context.bot.send_message.await_args_list
        self.assertEqual([call.kwargs['chat_id'] for call in calls], [-200, 11, 11, 11])
        self.assertTrue(all(len(call.kwargs['text']) <= 4000 for call in calls))
        self.assertIn("Report saved", update.effective_message.reply_text.call_args.args[0])

    def test_reporter_without_username_uses_display_name_and_id(self):
        update, _ = EndTaskAuthorizationTests().make_request()
        update.effective_user.username = None
        self.assertEqual(bot.reporter_arguments(update),
                         ["--reporter-id", "1", "--reporter-name", "Report Writer"])

    async def test_empty_recipients_send_nothing(self):
        update, context = EndTaskAuthorizationTests().make_request()
        context.bot = SimpleNamespace(send_message=AsyncMock())
        await bot.notify_report_received(update, context, {"id": "1"}, "Done")
        context.bot.send_message.assert_not_awaited()

    async def test_generated_assignment_id_is_used_in_confirmation(self):
        update, _ = EndTaskAuthorizationTests().make_request()
        result = SimpleNamespace(returncode=0, stdout="Saved 20261126-01: /data/2026-11-26.json\n")
        with patch.object(bot.subprocess, "run", return_value=result):
            self.assertEqual(await bot.run_task_update(update, ["assign_task"], None, "assign"), "20261126-01")
        update.effective_message.reply_text.assert_awaited_once_with("Task assigned: 20261126-01.")


class EngineerLabelTests(unittest.TestCase):
    def test_known_alias_and_removed_username(self):
        self.assertEqual(bot.engineer_label("MKAddison"), "@MKAddison - Yu Yu Aung")
        self.assertEqual(bot.engineer_label("ZymE3"), "@ZymE3 - Htet Wai Yan")
        self.assertEqual(bot.engineer_label("karmine"), "@karmine")
