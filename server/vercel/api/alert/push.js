// api/alert/push.js — Child device pushes an alert summary
const jwt = require('jsonwebtoken');
const { pendingAlerts, activePairs } = require('../_store');

const JWT_SECRET = process.env.JWT_SECRET || 'kova-relay-secret-change-in-production';

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Authenticate
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.replace('Bearer ', '');
  let decoded;
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired pair token' });
  }

  if (!decoded.paired) {
    return res.status(403).json({ error: 'Token is not a valid pair token' });
  }

  const { severity, app, alertType, timestamp, childName } = req.body || {};

  if (!severity || !app || !alertType) {
    return res.status(400).json({ error: 'severity, app, and alertType are required' });
  }

  // Build alert summary (NO content preview for privacy over internet)
  const alert = {
    id: `alert_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
    severity,
    app,
    alertType,
    childName: childName || 'Child',
    timestamp: timestamp || new Date().toISOString(),
    receivedAt: new Date().toISOString(),
  };

  // Add to pending queue
  if (!pendingAlerts.has(token)) {
    pendingAlerts.set(token, []);
  }
  const queue = pendingAlerts.get(token);
  queue.push(alert);

  // Keep max 100 pending alerts
  if (queue.length > 100) {
    queue.splice(0, queue.length - 100);
  }

  console.log(`🚨 Alert pushed: ${severity} ${alertType} on ${app}`);

  res.status(201).json({
    success: true,
    alertId: alert.id,
    queueSize: queue.length,
  });
};
