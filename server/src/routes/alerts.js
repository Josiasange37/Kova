// src/routes/alerts.js — Alert listing, detail, and actions
const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── GET /api/alerts ──
// Maps to: AlertHistoryScreen — list with filters
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { childId, appName, severity, resolved, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT a.id, a.child_id, a.app_name, a.alert_type, a.severity,
             a.sender_info, a.ai_confidence, a.is_resolved, a.resolved_action, a.created_at,
             c.name AS child_name
      FROM alerts a
      JOIN children c ON c.id = a.child_id
      WHERE c.parent_id = $1
    `;
    const params = [req.parentId];
    let paramIndex = 2;

    if (childId) {
      query += ` AND a.child_id = $${paramIndex++}`;
      params.push(childId);
    }

    if (appName) {
      query += ` AND a.app_name = $${paramIndex++}`;
      params.push(appName);
    }

    if (severity) {
      query += ` AND a.severity = $${paramIndex++}`;
      params.push(severity);
    }

    if (resolved !== undefined) {
      query += ` AND a.is_resolved = $${paramIndex++}`;
      params.push(resolved === 'true');
    }

    // Count total
    const countQuery = query.replace(/SELECT .+ FROM/, 'SELECT COUNT(*) as total FROM');
    const { rows: [{ total }] } = await pool.query(countQuery, params);

    // Add ordering and pagination
    query += ` ORDER BY a.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
    params.push(parseInt(limit, 10), parseInt(offset, 10));

    const { rows: alerts } = await pool.query(query, params);

    res.json({
      alerts: alerts.map((a) => ({
        id: a.id,
        childId: a.child_id,
        childName: a.child_name,
        appName: a.app_name,
        alertType: a.alert_type,
        severity: a.severity,
        senderInfo: a.sender_info,
        aiConfidence: parseFloat(a.ai_confidence),
        isResolved: a.is_resolved,
        resolvedAction: a.resolved_action,
        createdAt: a.created_at,
      })),
      total: parseInt(total, 10),
      page: parseInt(page, 10),
      limit: parseInt(limit, 10),
    });
  } catch (err) {
    console.error('List alerts error:', err);
    res.status(500).json({ error: 'Failed to list alerts' });
  }
});

// ── GET /api/alerts/:id ──
// Maps to: AlertDetailScreen — full alert detail with content_preview
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT a.*, c.name AS child_name
       FROM alerts a
       JOIN children c ON c.id = a.child_id
       WHERE a.id = $1 AND c.parent_id = $2`,
      [req.params.id, req.parentId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Alert not found' });
    }

    const a = rows[0];
    res.json({
      alert: {
        id: a.id,
        childId: a.child_id,
        childName: a.child_name,
        appName: a.app_name,
        alertType: a.alert_type,
        severity: a.severity,
        senderInfo: a.sender_info,
        contentPreview: a.content_preview,
        aiConfidence: parseFloat(a.ai_confidence),
        isResolved: a.is_resolved,
        resolvedAction: a.resolved_action,
        resolvedAt: a.resolved_at,
        createdAt: a.created_at,
      },
    });
  } catch (err) {
    console.error('Get alert error:', err);
    res.status(500).json({ error: 'Failed to get alert' });
  }
});

// ── PUT /api/alerts/:id/action ──
// Maps to: AlertDetailScreen action buttons (Block App, Dismiss, Report)
router.put('/:id/action', authMiddleware, async (req, res) => {
  try {
    const { action } = req.body;

    if (!['dismissed', 'blocked', 'reported'].includes(action)) {
      return res.status(400).json({ error: 'Action must be dismissed, blocked, or reported' });
    }

    // Verify alert belongs to parent's child
    const { rows: existing } = await pool.query(
      `SELECT a.id, a.child_id, a.app_name
       FROM alerts a
       JOIN children c ON c.id = a.child_id
       WHERE a.id = $1 AND c.parent_id = $2`,
      [req.params.id, req.parentId]
    );

    if (existing.length === 0) {
      return res.status(404).json({ error: 'Alert not found' });
    }

    const alert = existing[0];

    // If blocking, also update app_controls
    if (action === 'blocked') {
      await pool.query(
        `UPDATE app_controls SET is_blocked = true, updated_at = NOW()
         WHERE child_id = $1 AND app_name = $2`,
        [alert.child_id, alert.app_name]
      );
    }

    const { rows: [updated] } = await pool.query(
      `UPDATE alerts
       SET is_resolved = true, resolved_action = $1, resolved_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [action, req.params.id]
    );

    // Recalculate safety score
    const { rows: [stats] } = await pool.query(
      `SELECT COUNT(*) FILTER (WHERE NOT is_resolved) AS unresolved
       FROM alerts WHERE child_id = $1`,
      [alert.child_id]
    );

    const unresolved = parseInt(stats.unresolved, 10);
    const newScore = Math.max(0, 100 - unresolved * 10);

    await pool.query(
      'UPDATE children SET safety_score = $1 WHERE id = $2',
      [newScore, alert.child_id]
    );

    res.json({
      alert: {
        id: updated.id,
        isResolved: updated.is_resolved,
        resolvedAction: updated.resolved_action,
        resolvedAt: updated.resolved_at,
      },
      newSafetyScore: newScore,
    });
  } catch (err) {
    console.error('Alert action error:', err);
    res.status(500).json({ error: 'Failed to process alert action' });
  }
});

module.exports = router;
