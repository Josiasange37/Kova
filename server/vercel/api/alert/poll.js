// api/alert/poll.js — Parent device polls for pending alerts
const jwt = require('jsonwebtoken');
const { pendingAlerts } = require('../_store');

const JWT_SECRET = process.env.JWT_SECRET || 'kova-relay-secret-change-in-production';

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

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

  // Get and clear pending alerts
  const queue = pendingAlerts.get(token) || [];
  const alerts = [...queue]; // Copy
  queue.length = 0; // Clear

  res.json({
    alerts,
    count: alerts.length,
    polledAt: new Date().toISOString(),
  });
};
