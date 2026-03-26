// src/routes/apps.js — Monitored apps and controls
const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── GET /api/apps/:childId ──
// Maps to: AppControlScreen — list of apps with sensitivity/blocking controls
router.get('/:childId', authMiddleware, async (req, res) => {
  try {
    const { childId } = req.params;

    // Verify child belongs to parent
    const { rows: children } = await pool.query(
      'SELECT id FROM children WHERE id = $1 AND parent_id = $2',
      [childId, req.parentId]
    );
    if (children.length === 0) {
      return res.status(404).json({ error: 'Child not found' });
    }

    const { rows: apps } = await pool.query(
      `SELECT ma.id AS app_id, ma.app_name, ma.package_name, ma.monitoring_type,
              ma.is_connected, ma.icon_name, ma.icon_color,
              ac.id AS control_id, ac.sensitivity, ac.is_blocked, ac.is_enabled
       FROM monitored_apps ma
       LEFT JOIN app_controls ac ON ac.child_id = ma.child_id AND ac.app_name = ma.app_name
       WHERE ma.child_id = $1
       ORDER BY ma.app_name`,
      [childId]
    );

    res.json({
      apps: apps.map((a) => ({
        appId: a.app_id,
        controlId: a.control_id,
        appName: a.app_name,
        packageName: a.package_name,
        monitoringType: a.monitoring_type,
        isConnected: a.is_connected,
        iconName: a.icon_name,
        iconColor: a.icon_color,
        sensitivity: a.sensitivity || 'medium',
        isBlocked: a.is_blocked || false,
        isEnabled: a.is_enabled !== false,
      })),
    });
  } catch (err) {
    console.error('List apps error:', err);
    res.status(500).json({ error: 'Failed to list apps' });
  }
});

// ── PUT /api/apps/:controlId/control ──
// Maps to: AppControlScreen — sensitivity slider, block toggle, enable toggle
router.put('/:controlId/control', authMiddleware, async (req, res) => {
  try {
    const { sensitivity, isBlocked, isEnabled } = req.body;
    const { controlId } = req.params;

    // Verify control belongs to parent's child
    const { rows: existing } = await pool.query(
      `SELECT ac.id, ac.child_id, ac.app_name
       FROM app_controls ac
       JOIN children c ON c.id = ac.child_id
       WHERE ac.id = $1 AND c.parent_id = $2`,
      [controlId, req.parentId]
    );

    if (existing.length === 0) {
      return res.status(404).json({ error: 'App control not found' });
    }

    const updates = [];
    const values = [];
    let paramIdx = 1;

    if (sensitivity !== undefined) {
      if (!['low', 'medium', 'high'].includes(sensitivity)) {
        return res.status(400).json({ error: 'Sensitivity must be low, medium, or high' });
      }
      updates.push(`sensitivity = $${paramIdx++}`);
      values.push(sensitivity);
    }

    if (isBlocked !== undefined) {
      updates.push(`is_blocked = $${paramIdx++}`);
      values.push(isBlocked);
    }

    if (isEnabled !== undefined) {
      updates.push(`is_enabled = $${paramIdx++}`);
      values.push(isEnabled);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    updates.push(`updated_at = NOW()`);
    values.push(controlId);

    const { rows: [updated] } = await pool.query(
      `UPDATE app_controls SET ${updates.join(', ')} WHERE id = $${paramIdx}
       RETURNING id, app_name, sensitivity, is_blocked, is_enabled, updated_at`,
      values
    );

    res.json({
      app: {
        controlId: updated.id,
        appName: updated.app_name,
        sensitivity: updated.sensitivity,
        isBlocked: updated.is_blocked,
        isEnabled: updated.is_enabled,
        updatedAt: updated.updated_at,
      },
    });
  } catch (err) {
    console.error('Update app control error:', err);
    res.status(500).json({ error: 'Failed to update app control' });
  }
});

module.exports = router;
