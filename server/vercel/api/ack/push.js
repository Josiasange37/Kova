const { pendingAcks } = require('../_store');

// POST /api/ack/push
// Parent pushes an array of IDs of the elements they successfully received and saved locally.
module.exports = (req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const token = authHeader.split(' ')[1];
  const { ids } = req.body;

  if (!ids || !Array.isArray(ids)) {
    return res.status(400).json({ error: 'Missing or invalid ids' });
  }

  // Find or initialize the ACKs set for this token
  if (!pendingAcks.has(token)) {
    pendingAcks.set(token, new Set());
  }

  const ackSet = pendingAcks.get(token);
  ids.forEach(id => ackSet.add(id));

  // Also we can clear any pending History or Alerts by these IDs, 
  // but let's keep it simple: the child will just pull `pendingAcks` and clear the DB.
  
  return res.status(201).json({ success: true, count: ids.length });
};
