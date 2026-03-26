// src/routes/auth.js — Registration, Login, PIN verification
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── POST /api/auth/register ──
// Maps to: ParentProfileScreen "Continue" button
router.post('/register', async (req, res) => {
  try {
    const { name, phone, pin } = req.body;

    if (!name || !phone || !pin) {
      return res.status(400).json({ error: 'Name, phone, and pin are required' });
    }

    if (pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      return res.status(400).json({ error: 'PIN must be exactly 4 digits' });
    }

    // Check duplicate phone
    const existing = await pool.query('SELECT id FROM parents WHERE phone = $1', [phone]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Phone number already registered' });
    }

    const pinHash = await bcrypt.hash(pin, 10);
    const { rows: [parent] } = await pool.query(
      `INSERT INTO parents (name, phone, pin_hash)
       VALUES ($1, $2, $3)
       RETURNING id, name, phone, created_at`,
      [name, phone, pinHash]
    );

    // Create default settings
    await pool.query(
      `INSERT INTO settings (parent_id) VALUES ($1) ON CONFLICT DO NOTHING`,
      [parent.id]
    );

    const token = jwt.sign(
      { parentId: parent.id, name: parent.name },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({ token, parent });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// ── POST /api/auth/login ──
// Maps to: App re-open / login flow
router.post('/login', async (req, res) => {
  try {
    const { phone, pin } = req.body;

    if (!phone || !pin) {
      return res.status(400).json({ error: 'Phone and pin are required' });
    }

    const { rows } = await pool.query('SELECT * FROM parents WHERE phone = $1', [phone]);
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const parent = rows[0];
    const valid = await bcrypt.compare(pin, parent.pin_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { parentId: parent.id, name: parent.name },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      parent: {
        id: parent.id,
        name: parent.name,
        phone: parent.phone,
        created_at: parent.created_at,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

// ── POST /api/auth/verify-pin ──
// Maps to: AlertDetailScreen PIN entry bottom sheet
router.post('/verify-pin', authMiddleware, async (req, res) => {
  try {
    const { pin } = req.body;

    if (!pin) {
      return res.status(400).json({ error: 'PIN is required' });
    }

    const { rows } = await pool.query('SELECT pin_hash FROM parents WHERE id = $1', [req.parentId]);
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Parent not found' });
    }

    const valid = await bcrypt.compare(pin, rows[0].pin_hash);
    res.json({ valid });
  } catch (err) {
    console.error('verify-pin error:', err);
    res.status(500).json({ error: 'PIN verification failed' });
  }
});

module.exports = router;
