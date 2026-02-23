const { v4: uuidv4 } = require('uuid');
const { query }      = require('../config/db');

function blobToDataUri(buf, mime = 'image/jpeg') {
  if (!buf) return null;
  const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return b.length ? `data:${mime};base64,${b.toString('base64')}` : null;
}

// POST /api/groups
const createGroup = async (req, res) => {
  try {
    const { name, description, member_ids } = req.body;
    if (!name || !member_ids || !member_ids.length)
      return res.status(400).json({ success: false, message: 'name dan member_ids wajib diisi' });

    const convId  = uuidv4();
    const groupId = uuidv4();

    await query('INSERT INTO conversations (id, type) VALUES (?, "group")', [convId]);
    await query(
      'INSERT INTO groups_info (id, conversation_id, name, description, created_by) VALUES (?, ?, ?, ?, ?)',
      [groupId, convId, name, description || '', req.user.id]
    );

    const allMembers = [...new Set([...member_ids, req.user.id])];
    for (const uid of allMembers) {
      await query(
        'INSERT INTO conversation_members (id, conversation_id, user_id, role) VALUES (?, ?, ?, ?)',
        [uuidv4(), convId, uid, uid === req.user.id ? 'admin' : 'member']
      );
    }

    return res.status(201).json({ success: true, data: { conversation_id: convId, id: groupId, name } });
  } catch (err) {
    console.error('createGroup error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/groups/:conversation_id
const getGroupInfo = async (req, res) => {
  try {
    const rows = await query(`
      SELECT gi.*, u.name AS creator_name
      FROM groups_info gi
      JOIN users u ON u.id = gi.created_by
      WHERE gi.conversation_id = ?
    `, [req.params.conversation_id]);
    if (!rows.length) return res.status(404).json({ success: false, message: 'Grup tidak ditemukan' });
    const g = rows[0];
    return res.json({
      success: true,
      data: { ...g, avatar: blobToDataUri(g.avatar) }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PUT /api/groups/:conversation_id
const updateGroup = async (req, res) => {
  try {
    const { name, description } = req.body;
    const fields = []; const params = [];
    if (name)        { fields.push('name = ?');        params.push(name); }
    if (description !== undefined) { fields.push('description = ?'); params.push(description); }
    if (!fields.length) return res.status(400).json({ success: false, message: 'Tidak ada perubahan' });
    params.push(req.params.conversation_id);
    await query(`UPDATE groups_info SET ${fields.join(', ')} WHERE conversation_id = ?`, params);
    req.params.conversation_id = req.params.conversation_id;
    return getGroupInfo(req, res);
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// DELETE /api/groups/:conversation_id  — only admin/creator can delete
const deleteGroup = async (req, res) => {
  try {
    const { conversation_id } = req.params;

    // Check if requester is admin
    const member = await query(
      'SELECT role FROM conversation_members WHERE conversation_id = ? AND user_id = ?',
      [conversation_id, req.user.id]
    );
    if (!member.length) return res.status(403).json({ success: false, message: 'Anda bukan anggota grup' });
    if (member[0].role !== 'admin') return res.status(403).json({ success: false, message: 'Hanya admin yang bisa menghapus grup' });

    // Cascade delete: messages → conversation_members → groups_info → conversations
    await query('DELETE FROM message_status WHERE message_id IN (SELECT id FROM messages WHERE conversation_id = ?)', [conversation_id]);
    await query('DELETE FROM messages WHERE conversation_id = ?', [conversation_id]);
    await query('DELETE FROM conversation_members WHERE conversation_id = ?', [conversation_id]);
    await query('DELETE FROM groups_info WHERE conversation_id = ?', [conversation_id]);
    await query('DELETE FROM conversations WHERE id = ?', [conversation_id]);

    return res.json({ success: true, message: 'Grup dihapus' });
  } catch (err) {
    console.error('deleteGroup error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/groups/:conversation_id/avatar
const uploadGroupAvatar = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'File tidak ada' });
    await query('UPDATE groups_info SET avatar = ? WHERE conversation_id = ?', [req.file.buffer, req.params.conversation_id]);
    return res.json({ success: true, message: 'Avatar grup diupdate' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/groups/:conversation_id/members
const addMember = async (req, res) => {
  try {
    const { user_id } = req.body;
    if (!user_id) return res.status(400).json({ success: false, message: 'user_id diperlukan' });
    await query(
      'INSERT IGNORE INTO conversation_members (id, conversation_id, user_id, role) VALUES (?, ?, ?, "member")',
      [uuidv4(), req.params.conversation_id, user_id]
    );
    return res.json({ success: true, message: 'Member ditambahkan' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// DELETE /api/groups/:conversation_id/members/:user_id
const removeMember = async (req, res) => {
  try {
    await query(
      'DELETE FROM conversation_members WHERE conversation_id = ? AND user_id = ?',
      [req.params.conversation_id, req.params.user_id]
    );
    return res.json({ success: true, message: 'Member dihapus' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { createGroup, getGroupInfo, updateGroup, deleteGroup, uploadGroupAvatar, addMember, removeMember };
