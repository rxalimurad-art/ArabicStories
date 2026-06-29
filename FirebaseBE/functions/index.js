const functions = require('firebase-functions/v1');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ── Express API ────────────────────────────────────────────────────────────

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'Arabic Stories API' });
});

exports.api = functions.https.onRequest(app);

// ── Helpers ────────────────────────────────────────────────────────────────

async function getFCMToken(uid) {
  const doc = await db.collection('bayan_device_tokens').doc(uid).get();
  return doc.exists ? (doc.data().token ?? null) : null;
}

async function getDisplayName(uid) {
  const doc = await db.collection('bayan_users').doc(uid).get();
  return doc.exists ? (doc.data().displayName ?? 'Someone') : 'Someone';
}

async function sendPush(token, title, body, data) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (e) {
    console.error('FCM send error:', e);
  }
}

// ── Bayan: friend request created ─────────────────────────────────────────

exports.onFriendRequestCreated = functions.firestore
  .document('bayan_friend_requests/{requestId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data || data.status !== 'pending') return;

    const { fromUserId, toUserId } = data;
    const [token, senderName] = await Promise.all([
      getFCMToken(toUserId),
      getDisplayName(fromUserId),
    ]);
    if (!token) return;

    await sendPush(
      token,
      'New Friend Request',
      `${senderName} sent you a friend request`,
      { type: 'friend_request', fromUserId }
    );
  });

// ── Bayan: friend request accepted ────────────────────────────────────────

exports.onFriendRequestUpdated = functions.firestore
  .document('bayan_friend_requests/{requestId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== 'accepted') return;

    const { fromUserId, toUserId } = after;
    const [token, acceptorName] = await Promise.all([
      getFCMToken(fromUserId),
      getDisplayName(toUserId),
    ]);
    if (!token) return;

    await sendPush(
      token,
      'Friend Request Accepted',
      `${acceptorName} accepted your friend request`,
      { type: 'request_accepted', fromUserId: toUserId }
    );
  });

// ── Bayan: new message sent ───────────────────────────────────────────────

exports.onMessageCreated = functions.firestore
  .document('bayan_conversations/{convId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return;

    const { fromUserId, body } = data;
    const convId = context.params.convId;

    const [uid1, uid2] = convId.split('_');
    const recipientId = uid1 === fromUserId ? uid2 : uid1;

    const [token, senderName] = await Promise.all([
      getFCMToken(recipientId),
      getDisplayName(fromUserId),
    ]);
    if (!token) return;

    const preview = body.length > 80 ? body.slice(0, 77) + '…' : body;
    await sendPush(
      token,
      senderName,
      preview,
      { type: 'message', fromUserId, convId }
    );
  });

// ── Bayan: daily reading report email ─────────────────────────────────────
// Runs at 00:00 Asia/Karachi (GMT+5) and emails a reading summary. The job
// fires at midnight, so it reports on the day that just ended.
//
// Setup (one time):
//   cd functions && npm install
//   firebase deploy --only functions:dailyReadingReport
//
// NOTE: the Gmail App Password below is in plaintext — keep this repo private
// and rotate the password (Google Account → Security → App passwords) if it
// ever leaks.

const GMAIL_USER     = 'volutiontechnologies@gmail.com';
const GMAIL_PASSWORD = 'tneh ndls rjjq pffm';   // Gmail App Password
const REPORT_TO      = 'volutiontechnologies@gmail.com';

function karachiDate(d) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Karachi', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(d);
}

function fmtDuration(totalSeconds) {
  const s = Math.round(totalSeconds || 0);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m`;
  return `${s}s`;
}

async function buildAndSendReport() {
    // Report on the day that just ended (job runs at 00:00).
    const moment      = new Date(Date.now() - 60 * 60 * 1000);
    const todayStr    = karachiDate(moment);
    const sevenAgoStr = karachiDate(new Date(moment.getTime() - 6 * 24 * 3600 * 1000));

    // Single pass over all activity, grouped per user.
    // (Scales fine for now; see the "scaling" note if user/activity counts grow.)
    const snap = await db.collectionGroup('activity').get();
    const perUser = new Map(); // uid -> { todayV, todayS, allV, allS, lastDate }
    snap.forEach((doc) => {
      const uid = doc.ref.parent.parent && doc.ref.parent.parent.id;
      if (!uid) return;
      const d = doc.data();
      const v = Number(d.versesRead)  || 0;
      const s = Number(d.secondsRead) || 0;
      const u = perUser.get(uid) || { todayV: 0, todayS: 0, allV: 0, allS: 0, lastDate: '' };
      u.allV += v; u.allS += s;
      if (d.date === todayStr) { u.todayV += v; u.todayS += s; }
      if (d.date > u.lastDate) u.lastDate = d.date;
      perUser.set(uid, u);
    });

    // Active = read within the last 7 days (guests are included automatically).
    const active = [...perUser.entries()].filter(([, u]) => u.lastDate >= sevenAgoStr);

    // Resolve display names / guest flags for active users.
    const ids = active.map(([uid]) => uid);
    const meta = new Map();
    for (let i = 0; i < ids.length; i += 300) {
      const refs = ids.slice(i, i + 300).map((id) => db.collection('bayan_users').doc(id));
      const docs = refs.length ? await db.getAll(...refs) : [];
      docs.forEach((doc) => {
        const data = doc.data() || {};
        meta.set(doc.id, {
          name:  data.displayName || `User ${doc.id.slice(0, 6)}`,
          guest: data.isGuest === true,
        });
      });
    }

    // Totals across active users.
    let todayV = 0, todayS = 0, allV = 0, allS = 0;
    active.forEach(([, u]) => { todayV += u.todayV; todayS += u.todayS; allV += u.allV; allS += u.allS; });

    const rows = active
      .map(([uid, u]) => ({ uid, ...u, ...(meta.get(uid) || { name: uid, guest: false }) }))
      .sort((a, b) => b.todayV - a.todayV || b.allV - a.allV);

    // ── Email body: summary + top 50 table; full breakdown attached as CSV ──
    const card = (label, value) =>
      `<td style="padding:10px 14px;background:#F2F7F4;border-radius:10px;">
         <div style="font-size:12px;color:#5b6b62;">${label}</div>
         <div style="font-size:20px;font-weight:700;color:#15803D;">${value}</div>
       </td>`;

    const tableRows = rows.slice(0, 50).map((r, i) => `
      <tr style="border-bottom:1px solid #eee;">
        <td style="padding:6px 8px;color:#888;">${i + 1}</td>
        <td style="padding:6px 8px;">${r.name}${r.guest ? ' <span style="color:#999;font-size:11px;">(guest)</span>' : ''}</td>
        <td style="padding:6px 8px;text-align:right;">${r.todayV}</td>
        <td style="padding:6px 8px;text-align:right;">${fmtDuration(r.todayS)}</td>
        <td style="padding:6px 8px;text-align:right;">${r.allV}</td>
        <td style="padding:6px 8px;text-align:right;">${fmtDuration(r.allS)}</td>
      </tr>`).join('');

    const html = `
      <div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#1c1c1e;max-width:680px;">
        <h2 style="color:#15803D;margin:0 0 4px;">Quran Rifqah — Daily Report</h2>
        <div style="color:#666;margin-bottom:16px;">${todayStr} · ${active.length} active reader(s) (read in last 7 days)</div>

        <h3 style="margin:18px 0 8px;">Today (all users)</h3>
        <table cellspacing="8"><tr>${card('Ayahs read', todayV.toLocaleString())}${card('Time read', fmtDuration(todayS))}</tr></table>

        <h3 style="margin:18px 0 8px;">All time (all users)</h3>
        <table cellspacing="8"><tr>${card('Ayahs read', allV.toLocaleString())}${card('Time read', fmtDuration(allS))}</tr></table>

        <h3 style="margin:22px 0 8px;">Per reader${rows.length > 50 ? ' (top 50 — full list in the attached CSV)' : ''}</h3>
        <table style="border-collapse:collapse;width:100%;font-size:13px;">
          <thead><tr style="text-align:left;color:#5b6b62;border-bottom:2px solid #ddd;">
            <th style="padding:6px 8px;">#</th><th style="padding:6px 8px;">Reader</th>
            <th style="padding:6px 8px;text-align:right;">Today ayahs</th>
            <th style="padding:6px 8px;text-align:right;">Today time</th>
            <th style="padding:6px 8px;text-align:right;">All-time ayahs</th>
            <th style="padding:6px 8px;text-align:right;">All-time time</th>
          </tr></thead>
          <tbody>${tableRows || '<tr><td colspan="6" style="padding:10px;color:#888;">No active readers.</td></tr>'}</tbody>
        </table>
      </div>`;

    const csv = 'name,guest,today_ayahs,today_seconds,alltime_ayahs,alltime_seconds\n' +
      rows.map((r) => `"${String(r.name).replace(/"/g, '""')}",${r.guest},${r.todayV},${r.todayS},${r.allV},${r.allS}`).join('\n');

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: GMAIL_USER, pass: GMAIL_PASSWORD },
    });

    await transporter.sendMail({
      from: `Quran Rifqah <${GMAIL_USER}>`,
      to: REPORT_TO,
      subject: `Quran Rifqah — daily report ${todayStr}`,
      html,
      attachments: [{ filename: `report-${todayStr}.csv`, content: csv }],
    });

    console.log(`Daily report sent for ${todayStr}: ${active.length} active readers.`);
}

exports.dailyReadingReport = onSchedule(
  {
    schedule: '0 0 * * *',          // midnight…
    timeZone: 'Asia/Karachi',       // …GMT+5
  },
  async () => { await buildAndSendReport(); }
);

// ── Daily Checklist PWA: weekly activity report ─────────────────────────────
// Emails a summary of LAST week (previous Mon–Sun) every Monday 09:00 PKT.
// Source: the `checklist_entries` collection ({ taskKey, date, done, note }).
// Task metadata mirrors checklist-pwa/src/config/tasks.ts — keep in sync.

const CHECKLIST_GROUPS = [
  { key: 'deen', label: 'Deen & Arabic' },
  { key: 'projects', label: 'Projects' },
  { key: 'growth', label: 'Growth' },
];

const CHECKLIST_TASKS = [
  { key: 'arabic-memorization', group: 'deen', title: 'Arabic memorization' },
  { key: 'bayyinah-lectures', group: 'deen', title: 'Bayyinah lectures' },
  { key: 'quran-reading', group: 'deen', title: "Daily Qur'an reading" },
  { key: 'cap-mobile', group: 'projects', title: 'CAP Mobile' },
  { key: 'vida-driver', group: 'projects', title: 'VIDA Driver' },
  { key: 'my-app', group: 'projects', title: 'My app' },
  { key: 'career-learning', group: 'growth', title: 'New career learning' },
];

const escHtml = (s) =>
  String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function addDaysStr(s, n) {
  const [y, m, d] = s.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + n);
  return dt.toISOString().slice(0, 10);
}

// Karachi is a fixed UTC+5 (no DST), so the PKT calendar date is now + 5h.
function pktTodayStr() {
  return new Date(Date.now() + 5 * 3600 * 1000).toISOString().slice(0, 10);
}

function niceDate(s) {
  const [y, m, d] = s.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString('en-GB', {
    day: 'numeric', month: 'short', timeZone: 'UTC',
  });
}

async function buildAndSendWeeklyChecklist() {
  const today = pktTodayStr();
  const [yy, mm, dd] = today.split('-').map(Number);
  const dow = new Date(Date.UTC(yy, mm - 1, dd)).getUTCDay();   // 0=Sun … 6=Sat
  const daysSinceMon = (dow + 6) % 7;
  const thisMon = addDaysStr(today, -daysSinceMon);
  const lastMon = addDaysStr(thisMon, -7);
  const lastSun = addDaysStr(thisMon, -1);
  const weekDates = Array.from({ length: 7 }, (_, i) => addDaysStr(lastMon, i));

  const snap = await db.collection('checklist_entries')
    .where('date', '>=', lastMon).where('date', '<=', lastSun).get();

  // taskKey -> { 'YYYY-MM-DD' -> { done, note } }
  const byTask = {};
  snap.forEach((doc) => {
    const e = doc.data();
    if (!e || !e.taskKey || !e.date) return;
    (byTask[e.taskKey] ||= {})[e.date] = { done: !!e.done, note: e.note || '' };
  });

  const dayHeader = ['M', 'T', 'W', 'T', 'F', 'S', 'S']
    .map((L) => `<span style="display:inline-block;width:18px;text-align:center;">${L}</span>`)
    .join('');

  let totalDone = 0;
  let bestTask = null;
  let sectionsHtml = '';

  for (const g of CHECKLIST_GROUPS) {
    const tasks = CHECKLIST_TASKS.filter((t) => t.group === g.key);
    let rows = '';
    for (const t of tasks) {
      let doneCount = 0;
      const notes = [];
      const cells = weekDates.map((date) => {
        const cell = (byTask[t.key] || {})[date];
        const done = !!(cell && cell.done);
        if (done) doneCount++;
        if (cell && cell.note) notes.push(`${niceDate(date)}: ${escHtml(cell.note)}`);
        const bg = done ? '#5fa08e' : '#e2e2e2';
        return `<span style="display:inline-block;width:18px;text-align:center;"><span style="display:inline-block;width:12px;height:12px;border-radius:3px;background:${bg};vertical-align:middle;"></span></span>`;
      }).join('');

      totalDone += doneCount;
      if (!bestTask || doneCount > bestTask.count) bestTask = { title: t.title, count: doneCount };

      const cntColor = doneCount >= 5 ? '#2e7d5b' : doneCount === 0 ? '#c0392b' : '#1c2128';
      rows += `
        <tr style="border-top:1px solid #eee;">
          <td style="padding:9px 10px;font-size:14px;color:#1c2128;">${escHtml(t.title)}</td>
          <td style="padding:9px 10px;white-space:nowrap;">${cells}</td>
          <td style="padding:9px 10px;text-align:right;font-size:14px;font-weight:700;color:${cntColor};">${doneCount}/7</td>
        </tr>`;
      if (notes.length) {
        rows += `<tr><td colspan="3" style="padding:0 10px 9px 10px;font-size:12px;color:#777;">📝 ${notes.join(' &middot; ')}</td></tr>`;
      }
    }

    sectionsHtml += `
      <div style="margin:18px 0;">
        <div style="font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:#8c8678;margin:0 0 6px;">${escHtml(g.label)}</div>
        <table style="width:100%;border-collapse:collapse;background:#ffffff;border:1px solid #eee;border-radius:10px;overflow:hidden;">
          <thead><tr style="background:#fafafa;">
            <th style="text-align:left;padding:7px 10px;font-size:11px;color:#999;font-weight:600;">Task</th>
            <th style="text-align:left;padding:7px 10px;font-size:11px;color:#999;font-weight:600;white-space:nowrap;">${dayHeader}</th>
            <th style="text-align:right;padding:7px 10px;font-size:11px;color:#999;font-weight:600;">Done</th>
          </tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>`;
  }

  const possible = CHECKLIST_TASKS.length * 7;
  const pct = possible ? Math.round((totalDone / possible) * 100) : 0;
  const rangeLabel = `${niceDate(lastMon)} – ${niceDate(lastSun)}`;

  const html = `
    <div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:620px;margin:0 auto;padding:8px 4px;color:#1c2128;">
      <h1 style="font-size:20px;margin:0 0 2px;">Daily Checklist — weekly report</h1>
      <p style="margin:0 0 16px;color:#777;font-size:13px;">${rangeLabel} (last week)</p>
      <div style="background:#14171c;color:#ece6d8;border-radius:12px;padding:16px 18px;margin-bottom:6px;">
        <div style="font-size:32px;font-weight:700;color:#5fa08e;line-height:1;">${totalDone}<span style="font-size:18px;color:#8c8678;font-weight:500;"> / ${possible}</span></div>
        <div style="font-size:13px;color:#8c8678;margin-top:4px;">check-ins completed · ${pct}% of the week${bestTask ? ` · most consistent: <span style="color:#c9a24b;">${escHtml(bestTask.title)}</span> (${bestTask.count}/7)` : ''}</div>
      </div>
      ${sectionsHtml}
      <p style="color:#aaa;font-size:11px;margin-top:18px;">Sent automatically every Monday 09:00 PKT · deen-daily-checklist.web.app</p>
    </div>`;

  const csv = ['task_key,title,date,done,note']
    .concat(CHECKLIST_TASKS.flatMap((t) => weekDates.map((date) => {
      const cell = (byTask[t.key] || {})[date] || {};
      return `${t.key},"${t.title.replace(/"/g, '""')}",${date},${cell.done ? 1 : 0},"${String(cell.note || '').replace(/"/g, '""')}"`;
    })))
    .join('\n');

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: GMAIL_USER, pass: GMAIL_PASSWORD },
  });

  await transporter.sendMail({
    from: `Daily Checklist <${GMAIL_USER}>`,
    to: REPORT_TO,
    subject: `Daily Checklist — weekly report (${rangeLabel})`,
    html,
    attachments: [{ filename: `checklist-${lastMon}_to_${lastSun}.csv`, content: csv }],
  });

  console.log(`Weekly checklist report sent for ${rangeLabel}: ${totalDone}/${possible} check-ins.`);
}

exports.weeklyChecklistReport = onSchedule(
  {
    schedule: '0 9 * * 1',          // Monday 09:00…
    timeZone: 'Asia/Karachi',       // …GMT+5 (PKT)
  },
  async () => { await buildAndSendWeeklyChecklist(); }
);

// Manual on-demand trigger for testing (token-guarded):
//   https://<region>-<project>.cloudfunctions.net/weeklyChecklistReportNow?token=volution-weekly
exports.weeklyChecklistReportNow = functions.https.onRequest(async (req, res) => {
  if (req.query.token !== 'volution-weekly') {
    res.status(403).json({ error: 'forbidden' });
    return;
  }
  try {
    await buildAndSendWeeklyChecklist();
    res.json({ ok: true, sent: true });
  } catch (e) {
    console.error('weeklyChecklistReportNow error:', e);
    res.status(500).json({ error: String(e) });
  }
});

// ── Connect Bayan Qur'an reading → checklist "Daily Qur'an reading" ──────────
// When this user reads in the Bayan app, the checklist's quran-reading task is
// auto-completed for that day, so the PWA shows it ticked and streaks stay
// accurate. Reading lives in bayan_users/{uid}/activity ({ date, versesRead,
// secondsRead }); a day counts as "read" if verses or seconds > 0.

const BAYAN_READING_UID = 'Y5tVDGDvPMST5fqy9YGBhRneGyU2';
const QURAN_TASK_KEY = 'quran-reading';
const ARABIC_TASK_KEY = 'arabic-memorization';

// Mark a checklist task done for a given day (merge — keeps any note).
async function markChecklistDone(taskKey, date, source) {
  await db.collection('checklist_entries').doc(`${taskKey}__${date}`).set(
    { taskKey, date, done: true, source },
    { merge: true },
  );
}

const activityShowsRead = (d) =>
  (Number(d.versesRead) || 0) > 0 || (Number(d.secondsRead) || 0) > 0;

async function markQuranRead(date) {
  await db.collection('checklist_entries').doc(`${QURAN_TASK_KEY}__${date}`).set(
    { taskKey: QURAN_TASK_KEY, date, done: true, source: 'bayan' },
    { merge: true },                       // preserve any existing note
  );
}

// Sync the user's reading for the last `days` days into checklist_entries.
async function syncQuranReading(days = 60) {
  const cutoff = karachiDate(new Date(Date.now() - (days - 1) * 24 * 3600 * 1000));
  const snap = await db.collection('bayan_users').doc(BAYAN_READING_UID)
    .collection('activity').where('date', '>=', cutoff).get();
  const readDates = new Set();
  snap.forEach((doc) => {
    const d = doc.data();
    if (d && d.date && activityShowsRead(d)) readDates.add(d.date);
  });
  await Promise.all([...readDates].map(markQuranRead));
  console.log(`syncQuranReading: marked ${readDates.size} reading day(s) since ${cutoff}.`);
  return { markedDays: readDates.size, cutoff, dates: [...readDates].sort() };
}

// Real-time: a new/updated reading activity for this user → tick that day.
exports.syncQuranReadingOnActivity = functions.firestore
  .document('bayan_users/{uid}/activity/{activityId}')
  .onWrite(async (change, context) => {
    if (context.params.uid !== BAYAN_READING_UID) return;
    const after = change.after.exists ? change.after.data() : null;
    if (!after || !after.date || !activityShowsRead(after)) return;
    await markQuranRead(after.date);
  });

// Nightly self-heal at 00:10 PKT (covers history + any missed triggers).
exports.syncQuranReadingDaily = onSchedule(
  { schedule: '10 0 * * *', timeZone: 'Asia/Karachi' },
  async () => { await syncQuranReading(14); },
);

// Manual immediate sync (token-guarded) — backfill history now / testing.
//   /syncQuranReadingNow?token=volution-weekly&days=60
exports.syncQuranReadingNow = functions.https.onRequest(async (req, res) => {
  if (req.query.token !== 'volution-weekly') { res.status(403).json({ error: 'forbidden' }); return; }
  try {
    const days = Math.min(Number(req.query.days) || 60, 400);
    const result = await syncQuranReading(days);
    res.json({ ok: true, ...result });
  } catch (e) {
    console.error('syncQuranReadingNow error:', e);
    res.status(500).json({ error: String(e) });
  }
});

// ── Connect Memorize (Quran Rifqah) → checklist "Arabic memorization" ────────
// When the user marks any memorisation item done, count Arabic memorization as
// done for that day. Items live in bayan_users/{uid}/remember_groups/{groupId}
// as an embedded `items` array; each item has `id` and (when done) `isDone:true`.
const doneItemIds = (group) =>
  new Set(((group && group.items) || []).filter((it) => it && it.isDone === true).map((it) => it.id));

exports.syncMemorizeToArabicChecklist = functions.firestore
  .document('bayan_users/{uid}/remember_groups/{groupId}')
  .onWrite(async (change, context) => {
    if (context.params.uid !== BAYAN_READING_UID) return;
    const before = change.before.exists ? change.before.data() : null;
    const after  = change.after.exists ? change.after.data() : null;
    if (!after) return;

    const beforeDone = doneItemIds(before);
    const afterDone  = doneItemIds(after);
    // Only act when an item transitioned into "done".
    const newlyDone = [...afterDone].some((id) => !beforeDone.has(id));
    if (!newlyDone) return;

    const today = karachiDate(new Date());
    await markChecklistDone(ARABIC_TASK_KEY, today, 'bayan-memorize');
    console.log(`Arabic memorization marked done for ${today} (memorize item completed).`);
  });
