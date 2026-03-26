// src/routes/settings.js — Parent settings management
const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── GET /api/settings ──
// Maps to: SettingsScreen — loads all settings
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT s.*, p.name AS parent_name, p.phone AS parent_phone,
              c.name AS child_name, c.age AS child_age
       FROM settings s
       JOIN parents p ON p.id = s.parent_id
       LEFT JOIN children c ON c.parent_id = p.id
       WHERE s.parent_id = $1
       LIMIT 1`,
      [req.parentId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    const s = rows[0];
    res.json({
      settings: {
        parentName: s.parent_name,
        parentPhone: s.parent_phone,
        childName: s.child_name,
        childAge: s.child_age,
        quietHoursEnabled: s.quiet_hours_enabled,
        quietHoursStart: s.quiet_hours_start,
        quietHoursEnd: s.quiet_hours_end,
        language: s.language,
        notificationsEnabled: s.notifications_enabled,
        weeklyReportEnabled: s.weekly_report_enabled,
      },
    });
  } catch (err) {
    console.error('Get settings error:', err);
    res.status(500).json({ error: 'Failed to get settings' });
  }
});

// ── PUT /api/settings ──
// Maps to: SettingsScreen — save changes
router.put('/', authMiddleware, async (req, res) => {
  try {
    const {
      quietHoursEnabled,
      quietHoursStart,
      quietHoursEnd,
      language,
      notificationsEnabled,
      weeklyReportEnabled,
    } = req.body;

    const updates = [];
    const values = [];
    let paramIdx = 1;

    if (quietHoursEnabled !== undefined) {
      updates.push(`quiet_hours_enabled = $${paramIdx++}`);
      values.push(quietHoursEnabled);
    }

    if (quietHoursStart !== undefined) {
      updates.push(`quiet_hours_start = $${paramIdx++}`);
      values.push(quietHoursStart);
    }

    if (quietHoursEnd !== undefined) {
      updates.push(`quiet_hours_end = $${paramIdx++}`);
      values.push(quietHoursEnd);
    }

    if (language !== undefined) {
      updates.push(`language = $${paramIdx++}`);
      values.push(language);
    }

    if (notificationsEnabled !== undefined) {
      updates.push(`notifications_enabled = $${paramIdx++}`);
      values.push(notificationsEnabled);
    }

    if (weeklyReportEnabled !== undefined) {
      updates.push(`weekly_report_enabled = $${paramIdx++}`);
      values.push(weeklyReportEnabled);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    updates.push(`updated_at = NOW()`);
    values.push(req.parentId);

    const { rows: [updated] } = await pool.query(
      `UPDATE settings SET ${updates.join(', ')} WHERE parent_id = $${paramIdx}
       RETURNING *`,
      values
    );

    res.json({
      settings: {
        quietHoursEnabled: updated.quiet_hours_enabled,
        quietHoursStart: updated.quiet_hours_start,
        quietHoursEnd: updated.quiet_hours_end,
        language: updated.language,
        notificationsEnabled: updated.notifications_enabled,
        weeklyReportEnabled: updated.weekly_report_enabled,
      },
    });
  } catch (err) {
    console.error('Update settings error:', err);
    res.status(500).json({ error: 'Failed to update settings' });
  }
});

module.exports = router;
