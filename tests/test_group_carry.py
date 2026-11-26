import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

from telegram.error import TelegramError
from telegram.ext import ConversationHandler
from backend_python import bot


class GroupAndCarryTests(unittest.IsolatedAsyncioTestCase):
    def request(self, user=9, chat=-200):
        update = SimpleNamespace(
            effective_user=SimpleNamespace(id=user, username='employee'),
            effective_chat=SimpleNamespace(id=chat),
            effective_message=SimpleNamespace(reply_text=AsyncMock(), text='Progress'),
            callback_query=SimpleNamespace(answer=AsyncMock(), edit_message_text=AsyncMock(), data='end_task:0'),
        )
        context = SimpleNamespace(bot=SimpleNamespace(send_message=AsyncMock(), get_chat=AsyncMock()), user_data={}, bot_data={
            'task_assign_user_ids': {1}, 'standard_user_ids': {2}, 'allowed_chat_ids': {-100, -200},
            'group_chat_id': -200, 'group_chat_allowed': True, 'report_received_group_chat': True,
            'report_received_chat_ids': {-200, 1},
        })
        return update, context

    async def test_unlisted_group_member_can_report_but_not_assign_or_complete(self):
        update, context = self.request()
        await bot.start(update, context)
        self.assertIn('running', update.effective_message.reply_text.call_args.args[0])
        for handler in (bot.task_assign_start, bot.end_task_start, bot.end_task_select):
            self.assertEqual(await handler(update, context), ConversationHandler.END)
            self.assertIn('not authorized', (update.callback_query.edit_message_text if handler == bot.end_task_select else update.effective_message.reply_text).call_args.args[0])
        task = {'id': '20261126-01', 'task': 'Task', 'assigned_to': {'username': 'employee'}}
        for handler in (bot.report_save, bot.task_list_report_save):
            context.user_data[bot.report_key(update)] = task
            context.user_data[f'{bot.task_list_key(update)}:report_task'] = task
            context.bot.send_message.reset_mock()
            with patch.object(bot, 'run_task_update', new_callable=AsyncMock, return_value=task['id']) as save, patch.object(
                    bot, 'load_today_task_data', new_callable=AsyncMock, return_value={'tasks': [task]}):
                await handler(update, context)
                save.assert_awaited_once()
            self.assertEqual([call.kwargs['chat_id'] for call in context.bot.send_message.await_args_list], [-200, 1])

    def test_group_permission_does_not_grant_access_elsewhere_or_when_disabled(self):
        for chat in (9, -300):
            update, context = self.request(chat=chat)
            self.assertFalse(bot.report_authorized(update, context.bot_data))
        update, context = self.request()
        context.bot_data['group_chat_allowed'] = False
        self.assertFalse(bot.report_authorized(update, context.bot_data))

    def test_schedule_is_nine_am_myanmar_time(self):
        mmt = timezone(timedelta(hours=6, minutes=30))
        for hour, minute, due, next_day in [(0, 0, False, 26), (8, 59, False, 26), (9, 0, True, 27), (23, 0, True, 27)]:
            actual, next_run = bot.carry_schedule(datetime(2026, 11, 26, hour, minute, tzinfo=mmt))
            self.assertEqual(actual, due)
            self.assertEqual(next_run, datetime(2026, 11, next_day, 9, tzinfo=mmt))

    def test_group_configuration_validation(self):
        with patch.dict(os.environ, {'TELEGRAM_GROUP_CHAT_ID': '-200', 'TELEGRAM_GROUP_CHAT_ALLOWED': 'yes', 'TELEGRAM_REPORT_RECEIVED_GROUP_CHAT': 'yes'}):
            self.assertEqual(bot.group_settings()['group_chat_id'], -200)
            with patch.dict(os.environ, {'TELEGRAM_GROUP_CHAT_ID': '200'}):
                with self.assertRaises(ValueError):
                    bot.group_settings()

    async def test_auto_carry_sends_to_assignee_and_group_once_and_preserves_identity(self):
        _, context = self.request()
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'TASKS_DATA_DIR': folder}):
            script = Path(bot.__file__).with_name('update_tasks.py')
            subprocess.run([sys.executable, str(script), '--date', '2026-11-25', 'assign_task',
                            '--task', 'Task', '--username', 'employee', '--user-id', '2', '--description', 'Details'],
                           check=True, capture_output=True)
            await bot.auto_carry_forward('2026-11-26', context)
            self.assertEqual([call.kwargs['chat_id'] for call in context.bot.send_message.await_args_list], [-200, 2])
            data = json.loads((Path(folder) / '2026-11-26.json').read_text())
            self.assertEqual(data['tasks'][0]['id'], '20261125-01')
            self.assertEqual(data['tasks'][0]['assigned_to']['user_id'], 2)
            await bot.auto_carry_forward('2026-11-26', context)
            self.assertEqual(context.bot.send_message.await_count, 2)

    async def test_legacy_recipient_lookup_and_delivery_failure_isolation(self):
        _, context = self.request()
        context.bot.get_chat.return_value = SimpleNamespace(username='employee')
        async def send_message(chat_id, text):
            if chat_id == -200:
                raise TelegramError('blocked')
        context.bot.send_message.side_effect = send_message
        task = {'id': 'legacy', 'task': 'Task', 'description': 'Details', 'assigned_to': {'username': 'employee'}}
        with self.assertLogs(level='ERROR'):
            await bot.notify_carried_tasks(context, [task], '2026-11-26')
        self.assertEqual([call.kwargs['chat_id'] for call in context.bot.send_message.await_args_list], [-200, 2])
