'use strict';
// Daily files: { date: 'YYYY-MM-DD', updated_at: ISO timestamp, demo: boolean,
// tasks: [{ id, task, assigned_to: {username},
// description, employee_reports?: [{description, reported_at: ISO timestamp, reported_by?: {id, name, username}}],
// updated_at: ISO timestamp }] }. Legacy repo/name fields remain readable.
// Dates and timestamps are displayed in Asia/Yangon. No credentials or writes.
const TIME_ZONE = 'Asia/Yangon';
const ENGINEER_NAMES = new Map([
  ['di_qing_bai', 'PhyuPyarChanMyaeKyaw'],
  ['doloresax', 'Aung Khant Moe'],
  ['zyme3', 'Htet Wai Yan'],
  ['hmue_gyi', 'Hmue Sat San'],
  ['kyawswarhtunlinnaung', 'Kyaw Swar Htun'],
  ['mkaddison', 'Yu Yu Aung'],
]);
function telegramLabel(username, fallbackName = '') {
  const handle = username.replace(/^@/, '');
  const name = ENGINEER_NAMES.get(handle.toLowerCase()) || fallbackName;
  return handle ? `@${handle}${name ? ` - ${name}` : ''}` : name;
}
function telegramDisplayName(username, fallbackName = '') {
  const handle = (username || '').replace(/^@/, '');
  return ENGINEER_NAMES.get(handle.toLowerCase()) || fallbackName || '';
}
function engineerReveal(username, fallbackName = '', className = 'person') {
  const handle = (username || '').replace(/^@/, '');
  const name = telegramDisplayName(username, fallbackName) || 'Engineer';
  const wrap = node('span', 'engineer-reveal-wrap');
  const button = node('button', `${className} engineer-reveal`, name);
  button.type = 'button';
  button.title = 'Tap or hold to show @username and open Telegram';
  button.setAttribute('aria-label', button.title);
  wrap.append(button);
  if (!handle) return wrap;

  let revealed = false;
  let suppressClick = false;
  let holdTimer = null;
  const show = () => {
    if (!revealed) {
      const link = node('a', 'engineer-handle', `@${handle}`);
      link.href = `https://t.me/${handle}`;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      wrap.append(link);
      revealed = true;
    }
    window.open(`https://t.me/${handle}`, '_blank', 'noopener,noreferrer');
  };
  button.addEventListener('click', () => {
    if (suppressClick) { suppressClick = false; return; }
    show();
  });
  const startHold = (event) => {
    if (event.cancelable) event.preventDefault();
    holdTimer = setTimeout(() => { holdTimer = null; suppressClick = true; show(); }, 500);
  };
  const endHold = () => {
    if (holdTimer) { clearTimeout(holdTimer); holdTimer = null; }
  };
  button.addEventListener('touchstart', startHold, { passive: false });
  button.addEventListener('touchend', endHold);
  button.addEventListener('mousedown', startHold);
  button.addEventListener('mouseup', endHold);
  button.addEventListener('mouseleave', endHold);
  return wrap;
}
function telegramProfile(username) {
  const handle = username.replace(/^@/, '');
  return /^[a-zA-Z0-9_]{5,32}$/.test(handle) ? `https://t.me/${handle}` : undefined;
}
const $ = id => document.getElementById(id);
function todayKey() {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
  const value = type => parts.find(part => part.type === type).value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}
const dateObject = key => new Date(`${key}T12:00:00+06:30`);
const prettyDate = key => new Intl.DateTimeFormat('en-US', { timeZone: TIME_ZONE, weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).format(dateObject(key));
const time = iso => iso && Number.isFinite(Date.parse(iso)) ? new Intl.DateTimeFormat('en-US', { timeZone: TIME_ZONE, hour: 'numeric', minute: '2-digit' }).format(new Date(iso)) : '';
const reportDateTime = iso => iso && Number.isFinite(Date.parse(iso)) ? new Intl.DateTimeFormat('en-US', { timeZone: TIME_ZONE, year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(iso)) : '';
let selected = todayKey();
let month = selected.slice(0, 7);
let pending;
let generation = 0;
function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}
function linkOrText(text, href, className) {
  let safe = false;
  try { safe = ['https:', 'http:'].includes(new URL(href).protocol); } catch {}
  const element = node(safe ? 'a' : 'span', className, text);
  if (safe) { element.href = href; element.target = '_blank'; element.rel = 'noopener noreferrer'; }
  return element;
}
function renderCalendar() {
  const [year, number] = month.split('-').map(Number);
  $('month-label').textContent = new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(Date.UTC(year, number - 1, 1)));
  const grid = $('calendar-days');
  grid.replaceChildren();
  for (let i = 0; i < new Date(Date.UTC(year, number - 1, 1)).getUTCDay(); i++) grid.append(node('span'));
  const count = new Date(Date.UTC(year, number, 0)).getUTCDate();
  for (let day = 1; day <= count; day++) {
    const key = `${month}-${String(day).padStart(2, '0')}`;
    const button = node('button', `day${key === selected ? ' selected' : ''}${key === todayKey() ? ' today' : ''}`, day);
    button.type = 'button';
    button.setAttribute('aria-label', prettyDate(key));
    button.setAttribute('aria-pressed', String(key === selected));
    if (key === todayKey()) button.setAttribute('aria-current', 'date');
    button.addEventListener('click', () => selectDate(key));
    grid.append(button);
  }
  $('prev-month').disabled = month === '2000-01';
  $('next-month').disabled = month === '2100-12';
}
function card(task) {
  const article = node('article', 'task-card');
  const top = node('div', 'card-top');
  const taskTitle = node('div');
  taskTitle.append(node('span', 'field-label', `Task - ${task.id || '—'}`), node('span', 'repo', task.task || task.repo?.name || 'Untitled task'));
  if (task.status === 'completed') {
    taskTitle.append(node('span', 'task-status', '✅ Completed'));
  }
  const employee = node('div', 'employee');
  const assignee = task.assigned_to;
  const username = (typeof assignee === 'string' ? assignee : assignee.username || assignee.name || '').replace(/^@/, '');
  employee.append(node('span', 'field-label', 'Engineer'), engineerReveal(username, '', 'person'));
  top.append(taskTitle, employee);

  const dateRow = node('div', 'card-date-row');
  const created = node('time', 'task-created', reportDateTime(task.created_at) ? `Created ${reportDateTime(task.created_at)} · MMT` : 'Created time unavailable');
  if (reportDateTime(task.created_at)) created.dateTime = task.created_at;
  const expand = node('button', 'card-expand', '▾');
  expand.type = 'button';
  expand.title = 'Expand details';
  expand.setAttribute('aria-label', 'Expand details');
  dateRow.append(created, expand);

  const body = node('div', 'description-columns');
  const assignment = node('section', 'description assignment');
  assignment.append(node('span', 'field-label', 'Description'), node('p', '', task.description));
  const report = node('section', 'description employee-report');
  report.append(node('span', 'field-label', 'Engineer Report'));
  const reports = task.employee_reports || (task.employee_report ? [task.employee_report] : []);
  if (reports.length) {
    for (const entry of reports) {
      const reportEntry = node('div', 'report-entry');
      reportEntry.append(node('p', '', entry.description));
      const reporter = entry.reported_by;
      const reporterName = reporter?.name || '';
      const reporterUsername = reporter?.username || '';
      const reporterFallback = reporterName ||
        (reporter?.id != null ? `Telegram ID ${reporter.id}` : 'Unknown (not recorded)');
      const author = node('div', 'report-author');
      author.append(node('span', 'report-author-label', 'Report by: '),
        engineerReveal(reporterUsername, reporterFallback, 'report-author-value'));
      reportEntry.append(author);
      const reported = node('time', 'report-time', `Reported ${reportDateTime(entry.reported_at)} · MMT`);
      reported.dateTime = entry.reported_at;
      reportEntry.append(reported);
      report.append(reportEntry);
    }
  } else {
    report.append(node('p', 'report-pending', 'Awaiting Engineer Report'));
  }
  body.append(assignment, report);
  const bottom = node('div', 'card-bottom');
  const manager = node('div');
  const identity = node('span', 'manager');
  identity.append(node('span', 'manager-icon', 'OM'), document.createTextNode('Office Manager Agent'));
  manager.append(node('span', 'field-label', 'Assigned by'), identity);
  const stamp = node('time', 'timestamp', time(task.updated_at) ? `Updated ${time(task.updated_at)}` : '');
  if (time(task.updated_at)) stamp.dateTime = task.updated_at;
  bottom.append(manager, stamp);

  body.hidden = true;
  bottom.hidden = true;
  expand.addEventListener('click', () => {
    const opening = body.hidden;
    body.hidden = !opening;
    bottom.hidden = !opening;
    expand.textContent = opening ? '▴' : '▾';
    const label = opening ? 'Collapse details' : 'Expand details';
    expand.title = label;
    expand.setAttribute('aria-label', label);
  });
  article.append(top, dateRow, body, bottom);
  return article;
}
function message(title, detail, retry = false) {
  const box = node('div', 'empty');
  box.append(node('h2', '', title), node('p', '', detail));
  if (retry) {
    const button = node('button', 'button', 'Try again');
    button.addEventListener('click', () => loadLogs(selected));
    box.append(button);
  }
  $('logs').replaceChildren(box);
}
function validData(data, key) {
  return data && data.date === key && Array.isArray(data.tasks) && data.tasks.every(task =>
    task && typeof task.id === 'string' &&
    (typeof task.task === 'string' || task.repo && typeof task.repo.name === 'string') &&
    (typeof task.assigned_to === 'string' || task.assigned_to &&
      typeof task.assigned_to === 'object' &&
      (task.assigned_to.username === undefined || typeof task.assigned_to.username === 'string') &&
      (task.assigned_to.name === undefined || typeof task.assigned_to.name === 'string') &&
      (typeof task.assigned_to.username === 'string' || typeof task.assigned_to.name === 'string')) &&
    typeof task.description === 'string' &&
    (task.status === undefined || ['active', 'completed'].includes(task.status)) &&
    (task.employee_report == null || (typeof task.employee_report.description === 'string' &&
      typeof task.employee_report.reported_at === 'string' && Number.isFinite(Date.parse(task.employee_report.reported_at)))) &&
    (task.employee_reports === undefined || Array.isArray(task.employee_reports) &&
      task.employee_reports.every(entry => entry && typeof entry.description === 'string' &&
        typeof entry.reported_at === 'string' && Number.isFinite(Date.parse(entry.reported_at)))));
}
async function loadLogs(key) {
  const request = ++generation;
  pending?.abort();
  pending = new AbortController();
  $('logs').setAttribute('aria-busy', 'true');
  $('logs').replaceChildren();
  $('task-count').textContent = 'Loading logs…';
  $('updated-at').textContent = '';
  $('demo-notice').hidden = true;
  try {
    const response = await fetch(`./data/${key}.json`, { signal: pending.signal, cache: 'no-store' });
    if (request !== generation) return;
    if (response.status === 404) {
      $('task-count').textContent = '0 task logs';
      message('No logs for this day', 'Choose another date from the calendar.');
      return;
    }
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    if (request !== generation) return;
    if (!validData(data, key)) throw new Error('Invalid daily log format');
    $('task-count').textContent = `${data.tasks.length} task log${data.tasks.length === 1 ? '' : 's'}`;
    $('updated-at').textContent = time(data.updated_at) ? `Last update ${time(data.updated_at)} · MMT` : '';
    $('demo-notice').hidden = data.demo !== true;
    const updatedTime = task => {
      const timestamp = Date.parse(task.updated_at);
      return Number.isFinite(timestamp) ? timestamp : -Infinity;
    };
    const sortedTasks = [...data.tasks].sort((a, b) => updatedTime(b) - updatedTime(a));
    if (sortedTasks.length) $('logs').replaceChildren(...sortedTasks.map(card));
    else message('No logs for this day', 'Choose another date from the calendar.');
  } catch (error) {
    if (request !== generation || error.name === 'AbortError') return;
    $('task-count').textContent = 'Logs unavailable';
    message('Could not load this day', 'The log could not be read. Please try again.', true);
  } finally {
    if (request === generation) $('logs').setAttribute('aria-busy', 'false');
  }
}
function selectDate(key) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key) || key < '2000-01-01' || key > '2100-12-31' || !Number.isFinite(dateObject(key).getTime())) return;
  selected = key;
  month = key.slice(0, 7);
  $('date-picker').value = key;
  $('page-title').textContent = key === todayKey() ? 'Today’s log' : 'Daily log';
  $('date-label').textContent = prettyDate(key);
  renderCalendar();
  loadLogs(key);
}
function changeMonth(offset) {
  const [year, number] = month.split('-').map(Number);
  const next = new Date(Date.UTC(year, number - 1 + offset, 1));
  month = `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, '0')}`;
  renderCalendar();
}
function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  $('theme').textContent = theme === 'dark' ? 'Light mode' : 'Dark mode';
  $('theme').setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
}
let savedTheme;
try { savedTheme = localStorage.getItem('employee-log-theme'); } catch {}
setTheme(savedTheme === 'dark' || savedTheme === 'light' ? savedTheme : 'light');
$('theme').addEventListener('click', () => {
  const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  setTheme(theme);
  try { localStorage.setItem('employee-log-theme', theme); } catch {}
});
$('today').addEventListener('click', () => selectDate(todayKey()));
$('prev-month').addEventListener('click', () => changeMonth(-1));
$('next-month').addEventListener('click', () => changeMonth(1));
$('date-picker').addEventListener('change', event => selectDate(event.target.value));
selectDate(selected);
