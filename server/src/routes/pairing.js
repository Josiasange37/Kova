// src/routes/pairing.js — Device pairing (QR code / pairing code)
const express = require('express');
const { v4: uuidv4 } = require('uuid');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Generate a human-readable pairing code like KOVA-XXXX-XXXX
function generatePairingCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
  let code = 'KOVA-';
  for (let i = 0; i < 4; i++) code += chars[Math.floor(Math.random() * chars.length)];
  code += '-';
  for (let i = 0; i < 4; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

// ── POST /api/pairing/generate ──
// Maps to: WhatsappConnectScreen — generates QR data and pairing code
router.post('/generate', authMiddleware, async (req, res) => {
  try {
    const { childId } = req.body;

    if (!childId) {
      return res.status(400).json({ error: 'childId is required' });
    }

    // Verify child belongs to parent
    const { rows: children } = await pool.query(
      'SELECT id FROM children WHERE id = $1 AND parent_id = $2',
      [childId, req.parentId]
    );
    if (children.length === 0) {
      return res.status(404).json({ error: 'Child not found' });
    }

    // Expire any existing pending codes for this child
    await pool.query(
      `UPDATE pairing_codes SET status = 'expired'
       WHERE child_id = $1 AND status = 'pending'`,
      [childId]
    );

    const code = generatePairingCode();
    const { rows: [pairing] } = await pool.query(
      `INSERT INTO pairing_codes (parent_id, child_id, code, status, expires_at)
       VALUES ($1, $2, $3, 'pending', NOW() + INTERVAL '15 minutes')
       RETURNING id, code, status, expires_at`,
      [req.parentId, childId, code]
    );

    // QR data is the code itself — child app scans this
    res.status(201).json({
      code: pairing.code,
      qrData: JSON.stringify({
        type: 'kova-pair',
        code: pairing.code,
        childId,
      }),
      expiresAt: pairing.expires_at,
    });
  } catch (err) {
    console.error('Generate pairing error:', err);
    res.status(500).json({ error: 'Failed to generate pairing code' });
  }
});

// ── POST /api/pairing/connect ──
// Maps to: Child app using the pairing code to connect
router.post('/connect', async (req, res) => {
  try {
    const { code, deviceId } = req.body;

    if (!code || !deviceId) {
      return res.status(400).json({ error: 'Code and deviceId are required' });
    }

    // Find valid pairing code
    const { rows } = await pool.query(
      `SELECT pc.*, c.parent_id
       FROM pairing_codes pc
       JOIN children c ON c.id = pc.child_id
       WHERE pc.code = $1 AND pc.status = 'pending' AND pc.expires_at > NOW()`,
      [code]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Invalid or expired pairing code' });
    }

    const pairing = rows[0];

    // Update pairing status
    await pool.query(
      `UPDATE pairing_codes SET status = 'connected' WHERE id = $1`,
      [pairing.id]
    );

    // Update child with device ID
    await pool.query(
      `UPDATE children SET device_id = $1, is_online = true, last_seen = NOW()
       WHERE id = $2`,
      [deviceId, pairing.child_id]
    );

    // Mark WhatsApp as connected
    await pool.query(
      `UPDATE monitored_apps SET is_connected = true
       WHERE child_id = $1 AND app_name = 'WhatsApp'`,
      [pairing.child_id]
    );

    res.json({
      success: true,
      childId: pairing.child_id,
      parentId: pairing.parent_id,
    });
  } catch (err) {
    console.error('Pairing connect error:', err);
    res.status(500).json({ error: 'Failed to connect device' });
  }
});

module.exports = router;
