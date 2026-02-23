const jwt   = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { query }      = require('../config/db');
const firebaseAdmin  = require('../config/firebase');

async function sendPushNotification(targetUserId, { title, body, data }) {
  try {
    const rows = await query('SELECT fcm_token FROM users WHERE id = ?', [targetUserId]);
    const token = rows[0]?.fcm_token;
    if (!token) return;

    if (!firebaseAdmin) return;

    const message = {
      notification: { title, body },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'chats',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: 'default',
            badge: 1,
          },
        },
      },
      token: token,
    };

    await firebaseAdmin.messaging().send(message);
    // console.log(`🚀 Push sent to ${targetUserId}`);
  } catch (e) {
    console.error('Push notification error:', e.message);
  }
}

module.exports = (io) => {
  // Auth middleware for sockets
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Authentication error'));
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.userId;
      next();
    } catch {
      next(new Error('Authentication error'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    console.log(`🔌 User ${userId} connected (${socket.id})`);

    // Mark user online
    try {
      await query('UPDATE users SET is_online = TRUE, last_seen = NOW() WHERE id = ?', [userId]);
      // Notify contacts
      io.emit('user_online', { user_id: userId });
    } catch (e) { console.error(e); }

    // Join user's own room for private notifs
    socket.join(userId);

    // Join all conversation rooms
    try {
      const convs = await query(
        'SELECT conversation_id FROM conversation_members WHERE user_id = ?', [userId]
      );
      convs.forEach(c => socket.join(c.conversation_id));
    } catch (e) { console.error(e); }

    // Join a conversation room on demand
    socket.on('join_room', (conversationId) => {
      socket.join(conversationId);
    });

    // Send message via socket
    socket.on('send_message', async (data) => {
      try {
        const { conversation_id, content, type = 'text', reply_to } = data;
        if (!conversation_id || !content) return;

        // Check member
        const m = await query(
          'SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?',
          [conversation_id, userId]
        );
        if (!m.length) return;

        const msgId = uuidv4();
        await query(
          'INSERT INTO messages (id, conversation_id, sender_id, type, content, reply_to) VALUES (?, ?, ?, ?, ?, ?)',
          [msgId, conversation_id, userId, type, content, reply_to || null]
        );
        await query('UPDATE conversations SET updated_at = NOW() WHERE id = ?', [conversation_id]);
        await query(
          'INSERT INTO message_status (id, message_id, user_id, status) VALUES (?, ?, ?, "sent")',
          [uuidv4(), msgId, userId]
        );

        const rows = await query(
          'SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = ?',
          [msgId]
        );

        const msg = rows[0];
        // Broadcast to conversation room with all needed flags
        io.to(conversation_id).emit('new_message', {
          ...msg,
          is_edited : false,
          is_deleted: false,
        });

        // Mark delivered for online members
        const members = await query(
          'SELECT user_id FROM conversation_members WHERE conversation_id = ? AND user_id != ?',
          [conversation_id, userId]
        );
        for (const mem of members) {
          await query(
            'INSERT INTO message_status (id, message_id, user_id, status) VALUES (?, ?, ?, "delivered") ON DUPLICATE KEY UPDATE status = "delivered"',
            [uuidv4(), msgId, mem.user_id]
          );
        }
        io.to(conversation_id).emit('message_status_update', { message_id: msgId, status: 'delivered' });

        // ── PUSH NOTIFICATION ──
        // Send push to all members EXCEPT sender
        for (const mem of members) {
           sendPushNotification(mem.user_id, {
             title: msg.sender_name || 'Menyapa',
             body: type === 'text' ? content : `Mengirim ${type}`,
             data: {
               conversation_id: conversation_id,
               type: 'chat_message'
             }
           });
        }

      } catch (e) { console.error('send_message socket error:', e); }
    });

    // Typing indicator
    socket.on('typing', (data) => {
      const { conversation_id, is_typing } = data;
      socket.to(conversation_id).emit('typing', { user_id: userId, conversation_id, is_typing });
    });

    // Mark message as read
    socket.on('message_read', async (data) => {
      try {
        const { message_id, conversation_id } = data;
        await query(
          'INSERT INTO message_status (id, message_id, user_id, status) VALUES (?, ?, ?, "read") ON DUPLICATE KEY UPDATE status = "read", updated_at = NOW()',
          [uuidv4(), message_id, userId]
        );
        io.to(conversation_id).emit('message_read', { message_id, user_id: userId });
      } catch (e) { console.error(e); }
    });

    // ── Call Signalling ──────────────────────────────────────────────
    // Caller emits this to ring someone
    socket.on('call_user', (data) => {
      // data: { target_user_id, channel_name, caller_name, caller_avatar, is_video }
      io.to(data.target_user_id).emit('incoming_call', {
        caller_id   : userId,
        caller_name : data.caller_name,
        caller_avatar: data.caller_avatar || '',
        channel_name: data.channel_name,
        is_video    : data.is_video,
      });
    });

    // Callee accepts
    socket.on('accept_call', (data) => {
      // data: { caller_id, channel_name }
      io.to(data.caller_id).emit('call_accepted', {
        channel_name: data.channel_name,
      });
    });

    // Callee rejects
    socket.on('reject_call', (data) => {
      // data: { caller_id }
      io.to(data.caller_id).emit('call_rejected', {});
    });

    // Either side ends the ongoing call
    socket.on('end_call', (data) => {
      // data: { target_user_id }
      io.to(data.target_user_id).emit('call_ended', {});
    });

    // Disconnect
    socket.on('disconnect', async () => {
      console.log(`❌ User ${userId} disconnected`);
      try {
        await query('UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = ?', [userId]);
        io.emit('user_offline', { user_id: userId });
      } catch (e) { console.error(e); }
    });
  });
};
