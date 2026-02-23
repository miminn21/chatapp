const { v4: uuidv4 } = require('uuid');
const { query }      = require('../config/db');

function blobToDataUri(buf, mime = 'image/jpeg') {
  if (!buf) return null;
  const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return b.length ? `data:${mime};base64,${b.toString('base64')}` : null;
}

// GET /api/contacts
const getContacts = async (req, res) => {
  try {
    const rows = await query(`
      SELECT ct.id, ct.nickname, u.id AS user_id, u.name, u.phone,
             u.avatar, u.status_message, u.is_online, u.last_seen
      FROM contacts ct
      JOIN users u ON u.id = ct.contact_user_id
      WHERE ct.user_id = ?
      ORDER BY u.name ASC
    `, [req.user.id]);
    return res.json({ success: true, data: rows.map(r => ({ ...r, avatar: blobToDataUri(r.avatar), is_online: Boolean(r.is_online) })) });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/contacts
const addContact = async (req, res) => {
  try {
    const { contact_user_id, nickname } = req.body;
    if (!contact_user_id) return res.status(400).json({ success: false, message: 'contact_user_id diperlukan' });
    if (contact_user_id === req.user.id) return res.status(400).json({ success: false, message: 'Tidak bisa menambah diri sendiri' });

    const id = uuidv4();
    await query(
      'INSERT INTO contacts (id, user_id, contact_user_id, nickname) VALUES (?, ?, ?, ?)',
      [id, req.user.id, contact_user_id, nickname || null]
    );
    return res.status(201).json({ success: true, message: 'Kontak ditambahkan', data: { id } });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ success: false, message: 'Kontak sudah ada' });
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// DELETE /api/contacts/:id
const deleteContact = async (req, res) => {
  try {
    const { id } = req.params;
    await query('DELETE FROM contacts WHERE id = ? AND user_id = ?', [id, req.user.id]);
    return res.json({ success: true, message: 'Kontak dihapus' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getContacts, addContact, deleteContact };
