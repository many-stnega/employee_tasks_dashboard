import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from telegram.ext import ConversationHandler

from backend_python import bot


class EndTaskAuthorizationTests(unittest.IsolatedAsyncioTestCase):
    def make_request(self, user_id=1, chat_id=-100, managers=None):
        update = SimpleNamespace(
            effective_user=SimpleNamespace(id=user_id, username="employee"),
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
