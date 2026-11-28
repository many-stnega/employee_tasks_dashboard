import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

from backend_python import bot


class CarryNotificationWeekdayTests(unittest.IsolatedAsyncioTestCase):
    def make_context(self, weekdays):
        return SimpleNamespace(
            bot_data={
                "carry_notify_weekdays": set(weekdays),
                "standard_user_ids": set(),
            },
            bot=SimpleNamespace(send_message=AsyncMock()),
        )

    async def test_notification_skipped_on_unlisted_weekday(self):
        # 2026-11-26 is a Thursday.
        context = self.make_context({"mon", "wed"})
        await bot.notify_carried_tasks(
            context,
            [{"id": "x", "task": "Review", "description": "Do it",
              "assigned_to": {"username": "employee", "user_id": 7}}],
            "2026-11-26",
        )
        context.bot.send_message.assert_not_awaited()

    async def test_notification_sent_on_listed_weekday(self):
        context = self.make_context({"thu"})
        await bot.notify_carried_tasks(
            context,
            [{"id": "x", "task": "Review", "description": "Do it",
              "assigned_to": {"username": "employee", "user_id": 7}}],
            "2026-11-26",
        )
        context.bot.send_message.assert_awaited_once()
        self.assertEqual(
            context.bot.send_message.await_args.kwargs["chat_id"], 7
        )

    async def test_multiple_group_recipients(self):
        context = self.make_context({"thu"})
        context.bot_data["group_chat_allowed"] = True
        context.bot_data["group_chat_ids"] = {-100, -200}
        await bot.notify_carried_tasks(
            context,
            [{"id": "x", "task": "Review", "description": "Do it",
              "assigned_to": {"username": "employee", "user_id": 7}}],
            "2026-11-26",
        )
        self.assertEqual(
            {call.kwargs["chat_id"] for call in context.bot.send_message.await_args_list},
            {-100, -200, 7},
        )


if __name__ == "__main__":
    unittest.main()
