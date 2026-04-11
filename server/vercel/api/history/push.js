// api/history/push.js — Child device pushes web history summary
const jwt = require('jsonwebtoken');
const { pendingHistory } = require('../_store');

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

  const { encryptedData, iv, id } = req.body || {};

  if (!encryptedData || !iv) {
    return res.status(400).json({ error: 'encryptedData and iv are required' });
  }

  // Build blind history summary
  const history = {
    id: id || `history_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
    encryptedData,
    iv,
    receivedAt: new Date().toISOString(),
  };

  // Add to pending queue
  if (!pendingHistory.has(token)) {
    pendingHistory.set(token, []);
  }
  const queue = pendingHistory.get(token);
  queue.push(history);

  // Keep max 500 pending history entries
  if (queue.length > 500) {
    queue.splice(0, queue.length - 500);
  }

  res.status(201).json({
    message: 'History queued via relay',
    recordId: history.id,
    pendingCount: queue.length
  });
};
