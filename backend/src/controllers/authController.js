const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const path     = require('path');
const { v4: uuidv4 } = require('uuid');
const { query }      = require('../config/db');

// ─── helpers ────────────────────────────────────────────────────────────────
const admin = require('../config/firebase');

const generateToken = (userId) =>
  jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

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
    is_online     : Boolean(u.is_online),
    last_seen     : u.last_seen,
  };
}

// ─── POST /api/auth/firebase-register ──────────────────────────────────────
const firebaseRegister = async (req, res) => {
  try {
    const { idToken, name, password } = req.body;
    if (!idToken || !name || !password)
      return res.status(400).json({ success: false, message: 'idToken, name, password wajib diisi' });

    if (!admin) return res.status(503).json({ success: false, message: 'Firebase belum dikonfigurasi' });

    let decoded;
    try { decoded = await admin.auth().verifyIdToken(idToken); }
    catch (e) { return res.status(401).json({ success: false, message: 'Token Firebase tidak valid: ' + e.message }); }

    const phone = decoded.phone_number;
    if (!phone) return res.status(400).json({ success: false, message: 'Token tidak mengandung nomor telepon' });

    const existing = await query('SELECT id FROM users WHERE phone = ?', [phone]);
    if (existing.length) return res.status(409).json({ success: false, message: 'Nomor sudah terdaftar, silakan login' });

    const hashed = await bcrypt.hash(password, 10);
    const id     = uuidv4();
    await query('INSERT INTO users (id, phone, name, password) VALUES (?, ?, ?, ?)', [id, phone, name, hashed]);

    const token = generateToken(id);
    return res.status(201).json({ success: true, message: 'Registrasi berhasil', data: { id, name, phone, token } });
  } catch (err) {
    console.error('firebaseRegister error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── POST /api/auth/register (fallback – no OTP) ───────────────────────────
const register = async (req, res) => {
  try {
    const { name, phone, password, email } = req.body;
    if (!name || !phone || !password)
      return res.status(400).json({ success: false, message: 'name, phone, password wajib diisi' });

    const existing = await query('SELECT id FROM users WHERE phone = ?', [phone]);
    if (existing.length) return res.status(409).json({ success: false, message: 'Nomor sudah terdaftar' });

    const hashed = await bcrypt.hash(password, 10);
    const id     = uuidv4();
    await query('INSERT INTO users (id, phone, name, password, email) VALUES (?, ?, ?, ?, ?)',
      [id, phone, name, hashed, email || null]);

    const token = generateToken(id);
    return res.status(201).json({ success: true, message: 'Registrasi berhasil', data: { id, name, phone, email: email || null, token } });
  } catch (err) {
    console.error('register error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── POST /api/auth/login ───────────────────────────────────────────────────
const login = async (req, res) => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password)
      return res.status(400).json({ success: false, message: 'phone dan password wajib diisi' });

    const rows = await query('SELECT * FROM users WHERE phone = ?', [phone]);
    if (!rows.length) return res.status(401).json({ success: false, message: 'Nomor atau kata sandi salah' });

    const user  = rows[0];
    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).json({ success: false, message: 'Nomor atau kata sandi salah' });

    await query('UPDATE users SET is_online = TRUE, last_seen = NOW() WHERE id = ?', [user.id]);
    const token = generateToken(user.id);

    return res.json({ success: true, message: 'Login berhasil', data: { ...userRow(user), token } });
  } catch (err) {
    console.error('login error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── POST /api/auth/logout ──────────────────────────────────────────────────
const logout = async (req, res) => {
  try {
    await query('UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = ?', [req.user.id]);
    return res.json({ success: true, message: 'Berhasil keluar' });
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { firebaseRegister, register, login, logout };
