// src/routes/children.js — Child profile management
const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── POST /api/children ──
// Maps to: ChildProfileScreen "Continue" button
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { name, age } = req.body;

    if (!name || !age) {
      return res.status(400).json({ error: 'Name and age are required' });
    }

    if (age < 1 || age > 18) {
      return res.status(400).json({ error: 'Age must be between 1 and 18' });
    }

    const { rows: [child] } = await pool.query(
      `INSERT INTO children (parent_id, name, age)
       VALUES ($1, $2, $3)
       RETURNING id, parent_id, name, age, safety_score, is_online, created_at`,
      [req.parentId, name, age]
    );

    // Auto-create default monitored apps (matches MonitoredAppsScreen)
    const defaultApps = [
      { name: 'WhatsApp',  pkg: 'com.whatsapp',            type: 'connected',  icon: 'chat_rounded',       color: '#25D366' },
      { name: 'TikTok',    pkg: 'com.zhiliaoapp.musically', type: 'automatic', icon: 'music_note_rounded', color: '#010101' },
      { name: 'Facebook',  pkg: 'com.facebook.katana',     type: 'automatic',  icon: 'facebook_rounded',   color: '#1877F2' },
      { name: 'Instagram', pkg: 'com.instagram.android',   type: 'automatic',  icon: 'camera_alt_rounded', color: '#E4405F' },
      { name: 'SMS',       pkg: 'com.android.mms',         type: 'automatic',  icon: 'sms_rounded',        color: '#7C4DFF' },
    ];

    for (const app of defaultApps) {
      await pool.query(
        `INSERT INTO monitored_apps (child_id, app_name, package_name, monitoring_type, icon_name, icon_color)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT DO NOTHING`,
        [child.id, app.name, app.pkg, app.type, app.icon, app.color]
      );

      // Also create default app controls
      await pool.query(
        `INSERT INTO app_controls (child_id, app_name, sensitivity)
         VALUES ($1, $2, $3)
         ON CONFLICT DO NOTHING`,
        [child.id, app.name, app.name === 'WhatsApp' ? 'high' : 'medium']
      );
    }

    res.status(201).json({ child });
  } catch (err) {
    console.error('Create child error:', err);
    res.status(500).json({ error: 'Failed to create child profile' });
  }
});

// ── GET /api/children/:id ──
// Maps to: DashboardScreen header (child name, safety score)
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, parent_id, name, age, safety_score, is_online, device_id, last_seen, created_at
       FROM children WHERE id = $1 AND parent_id = $2`,
      [req.params.id, req.parentId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Child not found' });
    }

    res.json({ child: rows[0] });
  } catch (err) {
    console.error('Get child error:', err);
    res.status(500).json({ error: 'Failed to get child profile' });
  }
});

// ── GET /api/children ──
// Get all children for parent
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, age, safety_score, is_online, last_seen, created_at
       FROM children WHERE parent_id = $1
       ORDER BY created_at ASC`,
      [req.parentId]
    );

    res.json({ children: rows });
  } catch (err) {
    console.error('List children error:', err);
    res.status(500).json({ error: 'Failed to list children' });
  }
});

module.exports = router;
