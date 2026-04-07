// api/pair/verify.js — Parent device verifies a pairing code
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { pairingCodes, activePairs, pendingAlerts, cleanup } = require('../_store');

const JWT_SECRET = process.env.JWT_SECRET || 'kova-relay-secret-change-in-production';

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  cleanup();

  const { code, parentDeviceId } = req.body || {};

  if (!code || !parentDeviceId) {
    return res.status(400).json({ error: 'code and parentDeviceId are required' });
  }

  // Look up the code
  const entry = pairingCodes.get(code);

  if (!entry) {
    return res.status(404).json({ error: 'Invalid or expired pairing code' });
  }

  if (entry.expiresAt < Date.now()) {
    pairingCodes.delete(code);
    return res.status(410).json({ error: 'Pairing code has expired' });
  }

  // Generate pair token (JWT)
  const pairId = uuidv4();
  const pairToken = jwt.sign(
    {
      pairId,
      childDeviceId: entry.childDeviceId,
      parentDeviceId,
      paired: true,
    },
    JWT_SECRET,
    { expiresIn: '365d' } // Long-lived pair token
  );

  // Store the active pair
  activePairs.set(pairToken, {
    pairId,
    childDeviceId: entry.childDeviceId,
    parentDeviceId,
    pairedAt: Date.now(),
  });

  // Initialize alert queue for this pair
  pendingAlerts.set(pairToken, []);

  // Mark code as used
  entry.parentDeviceId = parentDeviceId;
  entry.pairToken = pairToken;
  pairingCodes.delete(code);

  console.log(`🔗 Pair verified: ${entry.childDeviceId} ↔ ${parentDeviceId}`);

  res.json({
    success: true,
    pairToken,
    childDeviceId: entry.childDeviceId,
    parentDeviceId,
    message: 'Devices paired successfully',
  });
};
