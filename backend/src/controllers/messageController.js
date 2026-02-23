const { v4: uuidv4 } = require('uuid');
const { query }      = require('../config/db');

// GET /api/conversations/:id/messages
const getMessages = async (req, res) => {
  try {
    const { id: conversation_id } = req.params;
    const { before, limit = 50 }  = req.query;

    const m = await query('SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?', [conversation_id, req.user.id]);
    if (!m.length) return res.status(403).json({ success: false, message: 'Akses ditolak' });

    let sql = `
      SELECT m.id, m.conversation_id, m.sender_id, m.type, m.content,
             m.reply_to, m.created_at, m.edited_at, m.deleted_at,
             u.name AS sender_name
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.conversation_id = ?`;
    const params = [conversation_id];

    if (before) { sql += ' AND m.created_at < ?'; params.push(before); }
    sql += ' ORDER BY m.created_at DESC LIMIT ?';
    params.push(Number(limit));

    const rows = await query(sql, params);

    // Mark messages as read
    for (const row of rows) {
      if (row.sender_id !== req.user.id) {
        await query(
          `INSERT INTO message_status (id, message_id, user_id, status) VALUES (?, ?, ?, 'read')
           ON DUPLICATE KEY UPDATE status = 'read', updated_at = NOW()`,
          [uuidv4(), row.id, req.user.id]
        );
      }
    }

    const data = rows.reverse().map(r => ({
      ...r,
      is_deleted: !!r.deleted_at,
      is_edited : !!r.edited_at,
      content   : r.deleted_at ? 'Pesan dihapus' : r.content,
    }));

    return res.json({ success: true, data });
  } catch (err) {
    console.error('getMessages error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/conversations/:id/messages
const sendMessage = async (req, res) => {
  try {
    const { id: conversation_id } = req.params;
    let { content, type = 'text', reply_to } = req.body;

    // If file uploaded (image/audio)
    if (req.file) {
      content = req.file.filename;
    }

    if (!content) return res.status(400).json({ success: false, message: 'Content wajib diisi' });

    const m = await query('SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?', [conversation_id, req.user.id]);
    if (!m.length) return res.status(403).json({ success: false, message: 'Akses ditolak' });

    const msgId = uuidv4();
    await query(
      'INSERT INTO messages (id, conversation_id, sender_id, type, content, reply_to) VALUES (?, ?, ?, ?, ?, ?)',
      [msgId, conversation_id, req.user.id, type, content, reply_to || null]
    );
    await query('UPDATE conversations SET updated_at = NOW() WHERE id = ?', [conversation_id]);
    await query(
      'INSERT INTO message_status (id, message_id, user_id, status) VALUES (?, ?, ?, "sent")',
      [uuidv4(), msgId, req.user.id]
    );

    const rows = await query(
      'SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = ?',
      [msgId]
    );

    return res.status(201).json({ success: true, data: { ...rows[0], is_deleted: false, is_edited: false } });
  } catch (err) {
    console.error('sendMessage error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PATCH /api/messages/:id  – edit content
const editMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { content } = req.body;
    if (!content || !content.trim())
      return res.status(400).json({ success: false, message: 'Content baru wajib diisi' });

    const rows = await query('SELECT * FROM messages WHERE id = ? AND deleted_at IS NULL', [id]);
    if (!rows.length) return res.status(404).json({ success: false, message: 'Pesan tidak ditemukan' });
    if (rows[0].sender_id !== req.user.id)
      return res.status(403).json({ success: false, message: 'Bukan pesan Anda' });

    await query('UPDATE messages SET content = ?, edited_at = NOW() WHERE id = ?', [content.trim(), id]);

    const updated = await query(
      'SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = ?',
      [id]
    );

    return res.json({ success: true, data: { ...updated[0], is_deleted: false, is_edited: true } });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// DELETE /api/messages/:id
const deleteMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const rows = await query('SELECT * FROM messages WHERE id = ?', [id]);
    if (!rows.length) return res.status(404).json({ success: false, message: 'Pesan tidak ditemukan' });
    if (rows[0].sender_id !== req.user.id)
      return res.status(403).json({ success: false, message: 'Bukan pesan Anda' });

    await query("UPDATE messages SET deleted_at = NOW(), content = 'Pesan dihapus', edited_at = NULL WHERE id = ?", [id]);
    return res.json({ success: true, message: 'Pesan dihapus', data: { id, is_deleted: true } });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getMessages, sendMessage, editMessage, deleteMessage };
