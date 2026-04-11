const { pendingAcks } = require('../_store');

// GET /api/ack/poll
// Child polls to see which items were successfully received by the Parent.
module.exports = (req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const token = authHeader.split(' ')[1];

  let ids = [];
  if (pendingAcks.has(token)) {
    // Array.from(Set)
    ids = Array.from(pendingAcks.get(token));
    // Clear them so they aren't returned twice
    pendingAcks.delete(token);
  }

  return res.status(200).json({ acks: ids });
};
