const { query } = require('../config/db');

function blobToDataUri(buf, mime = 'image/jpeg') {
  if (!buf) return null;
  const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return b.length ? `data:${mime};base64,${b.toString('base64')}` : null;
}

function userRow(u) {
  return {
    id            : u.id,
    name          : u.name,
    phone         : u.phone,
    email         : u.email,
    avatar        : blobToDataUri(u.avatar),
    cover_photo   : blobToDataUri(u.cover_photo),
    status_message: u.status_message,
    bio           : u.bio || null,
    is_online     : Boolean(u.is_online),
    last_seen     : u.last_seen,
  };
}

// GET /api/users/me
const getMe = async (req, res) => {
  try {
    const rows = await query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    if (!rows.length) return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    return res.json({ success: true, data: userRow(rows[0]) });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PUT /api/users/me
const updateMe = async (req, res) => {
  try {
    const { name, status_message, email, bio } = req.body;
    const fields = []; const params = [];
    if (name !== undefined)           { fields.push('name = ?');           params.push(name); }
    if (status_message !== undefined) { fields.push('status_message = ?'); params.push(status_message); }
    if (email !== undefined)          { fields.push('email = ?');          params.push(email); }
    if (bio !== undefined)            { fields.push('bio = ?');            params.push(bio); }
    if (!fields.length) return res.status(400).json({ success: false, message: 'Tidak ada perubahan' });
    params.push(req.user.id);
    await query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);
    return getMe(req, res);
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/users/me/avatar
const uploadAvatar = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'File tidak ada' });
    await query('UPDATE users SET avatar = ? WHERE id = ?', [req.file.buffer, req.user.id]);
    const rows = await query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    return res.json({ success: true, data: userRow(rows[0]) });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/users/me/cover
const uploadCover = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'File tidak ada' });
    await query('UPDATE users SET cover_photo = ? WHERE id = ?', [req.file.buffer, req.user.id]);
    const rows = await query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    return res.json({ success: true, data: userRow(rows[0]) });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/users/search?q=xxx
const searchUsers = async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.length < 2) return res.json({ success: true, data: [] });
    const rows = await query(
      'SELECT id, name, phone, avatar, bio, status_message, is_online, last_seen FROM users WHERE (name LIKE ? OR phone LIKE ?) AND id != ? LIMIT 30',
      [`%${q}%`, `%${q}%`, req.user.id]
    );
    return res.json({ success: true, data: rows.map(r => ({ ...r, avatar: blobToDataUri(r.avatar), is_online: Boolean(r.is_online) })) });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/users/:id
const getUser = async (req, res) => {
  try {
    const rows = await query(
      'SELECT id, name, phone, avatar, bio, status_message, is_online, last_seen FROM users WHERE id = ?',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    const u = rows[0];
    return res.json({ success: true, data: { ...u, avatar: blobToDataUri(u.avatar), is_online: Boolean(u.is_online) } });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/users/me/fcm-token
const updateFcmToken = async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ success: false, message: 'Token diperlukan' });

    await query('UPDATE users SET fcm_token = ? WHERE id = ?', [token, req.user.id]);
    return res.json({ success: true, message: 'FCM Token diperbarui' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getMe, updateMe, uploadAvatar, uploadCover, searchUsers, getUser, updateFcmToken };
