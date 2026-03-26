// src/routes/dashboard.js — Aggregated dashboard data
const express = require('express');
const pool = require('../db/pool');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// ── GET /api/dashboard/:childId ──
// Maps to: DashboardScreen — all sections (safety card, apps, recent activity)
router.get('/:childId', authMiddleware, async (req, res) => {
  try {
    const { childId } = req.params;

    // Verify child belongs to parent
    const { rows: children } = await pool.query(
      'SELECT * FROM children WHERE id = $1 AND parent_id = $2',
      [childId, req.parentId]
    );

    if (children.length === 0) {
      return res.status(404).json({ error: 'Child not found' });
    }

    const child = children[0];

    // Count unresolved alerts
    const { rows: [alertStats] } = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE NOT is_resolved) AS unresolved_count,
         COUNT(*) FILTER (WHERE NOT is_resolved AND severity IN ('high', 'critical')) AS critical_count
       FROM alerts WHERE child_id = $1`,
      [childId]
    );

    // Get monitored apps with status
    const { rows: apps } = await pool.query(
      `SELECT ma.app_name, ma.monitoring_type, ma.is_connected, ma.icon_name, ma.icon_color,
              ac.sensitivity, ac.is_blocked, ac.is_enabled
       FROM monitored_apps ma
       LEFT JOIN app_controls ac ON ac.child_id = ma.child_id AND ac.app_name = ma.app_name
       WHERE ma.child_id = $1
       ORDER BY ma.app_name`,
      [childId]
    );

    // Recent alerts (last 5)
    const { rows: recentAlerts } = await pool.query(
      `SELECT id, app_name, alert_type, severity, sender_info, ai_confidence, is_resolved, created_at
       FROM alerts WHERE child_id = $1
       ORDER BY created_at DESC LIMIT 5`,
      [childId]
    );

    const alertCount = parseInt(alertStats.unresolved_count, 10);

    res.json({
      child: {
        id: child.id,
        name: child.name,
        age: child.age,
        isOnline: child.is_online,
        lastSeen: child.last_seen,
      },
      safetyScore: child.safety_score,
      alertCount,
      criticalCount: parseInt(alertStats.critical_count, 10),
      hasAlerts: alertCount > 0,
      monitoredApps: apps.map((a) => ({
        appName: a.app_name,
        monitoringType: a.monitoring_type,
        isConnected: a.is_connected,
        iconName: a.icon_name,
        iconColor: a.icon_color,
        sensitivity: a.sensitivity,
        isBlocked: a.is_blocked,
        isEnabled: a.is_enabled,
      })),
      recentAlerts: recentAlerts.map((a) => ({
        id: a.id,
        appName: a.app_name,
        alertType: a.alert_type,
        severity: a.severity,
        senderInfo: a.sender_info,
        aiConfidence: parseFloat(a.ai_confidence),
        isResolved: a.is_resolved,
        createdAt: a.created_at,
      })),
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ error: 'Failed to load dashboard' });
  }
});

module.exports = router;
