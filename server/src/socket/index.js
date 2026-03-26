// src/socket/index.js — Socket.io real-time event handling
const pool = require('../db/pool');

function initSocket(io) {
  // Track connected clients
  const parentSockets = new Map();  // parentId → socket
  const childSockets = new Map();   // childId → socket

  io.on('connection', (socket) => {
    console.log(`🔌 Socket connected: ${socket.id}`);

    // ── Parent joins their room ──
    socket.on('parent:join', ({ parentId }) => {
      socket.join(`parent:${parentId}`);
      parentSockets.set(parentId, socket);
      console.log(`👤 Parent ${parentId} joined`);
    });

    // ── Child device joins and sends status ──
    socket.on('child:join', async ({ childId, deviceId }) => {
      socket.join(`child:${childId}`);
      childSockets.set(childId, socket);

      try {
        // Mark child as online
        const { rows } = await pool.query(
          `UPDATE children SET is_online = true, last_seen = NOW()
           WHERE id = $1 RETURNING parent_id`,
          [childId]
        );

        if (rows.length > 0) {
          // Notify parent
          io.to(`parent:${rows[0].parent_id}`).emit('child:status', {
            childId,
            isOnline: true,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (err) {
        console.error('child:join error:', err);
      }
    });

    // ── Child sends heartbeat / status updates ──
    socket.on('child:status', async ({ childId, batteryLevel }) => {
      try {
        const { rows } = await pool.query(
          `UPDATE children SET is_online = true, last_seen = NOW()
           WHERE id = $1 RETURNING parent_id`,
          [childId]
        );

        if (rows.length > 0) {
          io.to(`parent:${rows[0].parent_id}`).emit('child:status', {
            childId,
            isOnline: true,
            batteryLevel,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (err) {
        console.error('child:status error:', err);
      }
    });

    // ── Child sends screen time data ──
    socket.on('child:screentime', async ({ childId, totalMinutes, appBreakdown }) => {
      try {
        const { rows } = await pool.query(
          'SELECT parent_id FROM children WHERE id = $1',
          [childId]
        );

        if (rows.length > 0) {
          io.to(`parent:${rows[0].parent_id}`).emit('child:screentime', {
            childId,
            totalMinutes,
            appBreakdown,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (err) {
        console.error('child:screentime error:', err);
      }
    });

    // ── New alert from child device (AI detection) ──
    socket.on('alert:create', async (alertData) => {
      try {
        const { childId, appName, alertType, severity, senderInfo, contentPreview, aiConfidence } = alertData;

        const { rows: [alert] } = await pool.query(
          `INSERT INTO alerts (child_id, app_name, alert_type, severity, sender_info, content_preview, ai_confidence)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING *`,
          [childId, appName, alertType, severity, senderInfo, contentPreview, aiConfidence]
        );

        // Update safety score
        const { rows: [stats] } = await pool.query(
          `SELECT COUNT(*) FILTER (WHERE NOT is_resolved) AS unresolved
           FROM alerts WHERE child_id = $1`,
          [childId]
        );
        const newScore = Math.max(0, 100 - parseInt(stats.unresolved, 10) * 10);
        await pool.query('UPDATE children SET safety_score = $1 WHERE id = $2', [newScore, childId]);

        // Get parent
        const { rows: children } = await pool.query(
          'SELECT parent_id FROM children WHERE id = $1', [childId]
        );

        if (children.length > 0) {
          io.to(`parent:${children[0].parent_id}`).emit('alert:new', {
            id: alert.id,
            childId: alert.child_id,
            appName: alert.app_name,
            alertType: alert.alert_type,
            severity: alert.severity,
            senderInfo: alert.sender_info,
            aiConfidence: parseFloat(alert.ai_confidence),
            createdAt: alert.created_at,
            newSafetyScore: newScore,
          });
        }
      } catch (err) {
        console.error('alert:create error:', err);
      }
    });

    // ── App blocked on child device ──
    socket.on('app:blocked', async ({ childId, appName }) => {
      try {
        const { rows } = await pool.query(
          'SELECT parent_id FROM children WHERE id = $1', [childId]
        );

        if (rows.length > 0) {
          io.to(`parent:${rows[0].parent_id}`).emit('app:blocked', {
            childId,
            appName,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (err) {
        console.error('app:blocked error:', err);
      }
    });

    // ── Disconnect handling ──
    socket.on('disconnect', async () => {
      console.log(`🔌 Socket disconnected: ${socket.id}`);

      // Find and mark child as offline
      for (const [childId, s] of childSockets.entries()) {
        if (s.id === socket.id) {
          childSockets.delete(childId);

          try {
            const { rows } = await pool.query(
              `UPDATE children SET is_online = false, last_seen = NOW()
               WHERE id = $1 RETURNING parent_id`,
              [childId]
            );

            if (rows.length > 0) {
              io.to(`parent:${rows[0].parent_id}`).emit('child:status', {
                childId,
                isOnline: false,
                timestamp: new Date().toISOString(),
              });
            }
          } catch (err) {
            console.error('disconnect child:status error:', err);
          }
          break;
        }
      }

      // Clean up parent sockets
      for (const [parentId, s] of parentSockets.entries()) {
        if (s.id === socket.id) {
          parentSockets.delete(parentId);
          break;
        }
      }
    });
  });
}

module.exports = initSocket;
