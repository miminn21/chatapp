const { v4: uuidv4 } = require('uuid');
const { query }      = require('../config/db');

function blobToDataUri(buf, mime = 'image/jpeg') {
  if (!buf) return null;
  const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return b.length ? `data:${mime};base64,${b.toString('base64')}` : null;
}

function mapConversation(r) {
  return {
    id               : r.id,
    type             : r.type,
    updated_at       : r.updated_at,
    last_message     : r.last_message     || null,
    last_message_at  : r.last_message_at  || null,
    last_message_type: r.last_message_type|| null,
    unread_count     : Number(r.unread_count || 0),
    name             : r.type === 'group' ? r.group_name  : r.other_user_name,
    avatar           : blobToDataUri(r.type === 'group' ? r.group_avatar : r.other_user_avatar),
    other_user: r.type === 'dm' ? {
      id      : r.other_user_id,
      name    : r.other_user_name,
      phone   : r.other_user_phone,
      is_online: Boolean(r.other_user_online),
      last_seen: r.other_user_last_seen,
    } : null,
  };
}

// GET /api/conversations
const getConversations = async (req, res) => {
  try {
    const rows = await query(`
      SELECT
        c.id, c.type, c.updated_at,
        (SELECT content  FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message,
        (SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message_at,
        (SELECT type     FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message_type,
        (SELECT COUNT(*) FROM messages m
           JOIN message_status ms ON ms.message_id = m.id
           WHERE m.conversation_id = c.id AND ms.user_id = ? AND ms.status != 'read'
        ) AS unread_count,
        gi.name AS group_name, gi.avatar AS group_avatar,
        u.id    AS other_user_id,  u.name  AS other_user_name,
        u.phone AS other_user_phone, u.avatar AS other_user_avatar,
        u.is_online AS other_user_online, u.last_seen AS other_user_last_seen
      FROM conversations c
      JOIN conversation_members cm ON c.id = cm.conversation_id AND cm.user_id = ?
      LEFT JOIN groups_info gi ON gi.conversation_id = c.id
      LEFT JOIN conversation_members cm2 ON cm2.conversation_id = c.id AND cm2.user_id != ? AND c.type = 'dm'
      LEFT JOIN users u ON u.id = cm2.user_id
      ORDER BY c.updated_at DESC
    `, [req.user.id, req.user.id, req.user.id]);

    return res.json({ success: true, data: rows.map(mapConversation) });
  } catch (err) {
    console.error('getConversations error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/conversations/:id
const getConversation = async (req, res) => {
  try {
    const { id } = req.params;
    // Check membership
    const member = await query('SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?', [id, req.user.id]);
    if (!member.length) return res.status(403).json({ success: false, message: 'Akses ditolak' });

    const rows = await query(`
      SELECT c.id, c.type, c.updated_at,
        gi.name AS group_name, gi.description AS group_description, gi.avatar AS group_avatar,
        gi.created_by AS group_created_by,
        u.id   AS other_user_id, u.name AS other_user_name,
        u.phone AS other_user_phone, u.avatar AS other_user_avatar,
        u.is_online AS other_user_online, u.last_seen AS other_user_last_seen
      FROM conversations c
      LEFT JOIN groups_info gi ON gi.conversation_id = c.id
      LEFT JOIN conversation_members cm2 ON cm2.conversation_id = c.id AND cm2.user_id != ? AND c.type = 'dm'
      LEFT JOIN users u ON u.id = cm2.user_id
      WHERE c.id = ?
    `, [req.user.id, id]);

    if (!rows.length) return res.status(404).json({ success: false, message: 'Percakapan tidak ditemukan' });

    const r = rows[0];
    const data = {
      id        : r.id,
      type      : r.type,
      updated_at: r.updated_at,
      name      : r.type === 'group' ? r.group_name : r.other_user_name,
      avatar    : blobToDataUri(r.type === 'group' ? r.group_avatar : r.other_user_avatar),
      other_user: r.type === 'dm' ? { id: r.other_user_id, name: r.other_user_name, phone: r.other_user_phone, is_online: Boolean(r.other_user_online), last_seen: r.other_user_last_seen } : null,
      group     : r.type === 'group' ? { name: r.group_name, description: r.group_description, created_by: r.group_created_by } : null,
    };
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/conversations/dm
const createOrGetDM = async (req, res) => {
  try {
    const { other_user_id } = req.body;
    if (!other_user_id) return res.status(400).json({ success: false, message: 'other_user_id diperlukan' });

    const existing = await query(`
      SELECT c.id FROM conversations c
      JOIN conversation_members a ON a.conversation_id = c.id AND a.user_id = ?
      JOIN conversation_members b ON b.conversation_id = c.id AND b.user_id = ?
      WHERE c.type = 'dm'
      LIMIT 1
    `, [req.user.id, other_user_id]);

    if (existing.length) return res.json({ success: true, data: { id: existing[0].id } });

    const convId = uuidv4();
    await query('INSERT INTO conversations (id, type) VALUES (?, "dm")', [convId]);
    await query(
      'INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?, ?, ?), (?, ?, ?)',
      [uuidv4(), convId, req.user.id, uuidv4(), convId, other_user_id]
    );
    return res.status(201).json({ success: true, data: { id: convId } });
  } catch (err) {
    console.error('createOrGetDM error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/conversations/:id/members
const getMembers = async (req, res) => {
  try {
    const rows = await query(`
      SELECT u.id, u.name, u.phone, u.avatar, u.is_online, u.last_seen, cm.role
      FROM conversation_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.conversation_id = ?
    `, [req.params.id]);
    return res.json({ success: true, data: rows.map(r => ({ ...r, avatar: blobToDataUri(r.avatar), is_online: Boolean(r.is_online) })) });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getConversations, getConversation, createOrGetDM, getMembers };
