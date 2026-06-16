const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

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
