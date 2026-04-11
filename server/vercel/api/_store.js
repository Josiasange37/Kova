// api/_store.js — In-memory store shared across serverless invocations
// NOTE: On Vercel, this resets on each cold start. For production, use Vercel KV.

// Pairing codes: { code: { childDeviceId, parentDeviceId?, pairToken?, expiresAt } }
const pairingCodes = new Map();

// Pending alerts: { pairToken: [{ severity, app, alertType, timestamp }] }
const pendingAlerts = new Map();

// Pending history: { pairToken: [{ id, url, title, timestamp }] }
const pendingHistory = new Map();

// Active pairs: { pairToken: { childDeviceId, parentDeviceId, pairedAt } }
const activePairs = new Map();

// Pending ACKs: { pairToken: Set([id, id2, ...]) }
const pendingAcks = new Map();

// Cleanup expired codes every invocation
function cleanup() {
  const now = Date.now();
  for (const [code, data] of pairingCodes.entries()) {
    if (data.expiresAt < now) {
      pairingCodes.delete(code);
    }
  }
}

module.exports = { pairingCodes, pendingAlerts, pendingHistory, activePairs, pendingAcks, cleanup };
