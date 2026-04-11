// api/pair/register.js — Parent device registers a pairing code
const { pairingCodes, cleanup } = require('../_store');

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

  if (!/^\d{6}$/.test(code)) {
    return res.status(400).json({ error: 'Code must be exactly 6 digits' });
  }

  // Register code (expires in 10 minutes)
  pairingCodes.set(code, {
    parentDeviceId,
    childDeviceId: null,
    pairToken: null,
    expiresAt: Date.now() + 10 * 60 * 1000,
    registeredAt: Date.now(),
  });

  console.log(`📱 Code ${code} registered by parent device ${parentDeviceId}`);

  res.status(201).json({
    success: true,
    code,
    expiresIn: 600,
    message: 'Pairing code registered. Waiting for child to claim.',
  });
};
