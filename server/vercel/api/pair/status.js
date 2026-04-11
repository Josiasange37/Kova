// api/pair/status.js — Parent device polls status of a registered pairing code
const { pairingCodes, cleanup } = require('../_store');

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  cleanup();

  const { code } = req.query || {};

  if (!code) {
    return res.status(400).json({ error: 'code is required' });
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

  // Has it been claimed?
  if (entry.pairToken && entry.childDeviceId) {
    // Parent can now get the pair token.
    // Also we can safely delete from pairingCodes to prevent reuse,
    // since both sides now have the pairToken.
    const pairToken = entry.pairToken;
    const childDeviceId = entry.childDeviceId;
    pairingCodes.delete(code);

    return res.json({
      paired: true,
      pairToken,
      childDeviceId,
      message: 'Pairing complete',
    });
  } else {
    return res.json({
      paired: false,
      message: 'Waiting for child device',
    });
  }
};
