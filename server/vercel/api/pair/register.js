// api/pair/register.js — Child device registers its pairing code
const { pairingCodes, cleanup } = require('../_store');

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  cleanup();

  const { code, childDeviceId } = req.body || {};

  if (!code || !childDeviceId) {
    return res.status(400).json({ error: 'code and childDeviceId are required' });
  }

  if (!/^\d{6}$/.test(code)) {
    return res.status(400).json({ error: 'Code must be exactly 6 digits' });
  }

  // Register code (expires in 10 minutes)
  pairingCodes.set(code, {
    childDeviceId,
    parentDeviceId: null,
    pairToken: null,
    expiresAt: Date.now() + 10 * 60 * 1000,
    registeredAt: Date.now(),
  });

  console.log(`📱 Code ${code} registered by child device ${childDeviceId}`);

  res.status(201).json({
    success: true,
    code,
    expiresIn: 600,
    message: 'Pairing code registered. Waiting for parent to verify.',
  });
};
