const express = require('express');
const fs = require('fs');
const path = require('path');

const STORE_PATH = path.join(__dirname, '../../data/relay_store.json');
const SAVE_INTERVAL_MS = 30_000;
const MAX_STORED_ALERTS = 100;
const MAX_STORED_HISTORY = 50;

let alertStore = new Map();
let historyStore = new Map();
let ackStore = new Map();
let childProfiles = new Map();

function generateId() {
  const { v4: uuidv4 } = require('uuid');
  return uuidv4();
}

function toPojo(map) {
  return Array.from(map.entries());
}
function fromPojo(entries) {
  return new Map(entries);
}

function saveToDisk() {
  try {
    const dir = path.dirname(STORE_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const data = JSON.stringify({
      alertStore: toPojo(alertStore),
      historyStore: toPojo(historyStore),
      ackStore: toPojo(ackStore),
      childProfiles: toPojo(childProfiles),
      savedAt: new Date().toISOString(),
    });
    fs.writeFileSync(STORE_PATH, data, 'utf-8');
  } catch (e) {
    console.error('Failed to persist relay store:', e.message);
  }
}

function loadFromDisk() {
  try {
    if (!fs.existsSync(STORE_PATH)) return false;
    const raw = fs.readFileSync(STORE_PATH, 'utf-8');
    const data = JSON.parse(raw);
    alertStore = fromPojo(data.alertStore || []);
    historyStore = fromPojo(data.historyStore || []);
    ackStore = fromPojo(data.ackStore || []);
    childProfiles = fromPojo(data.childProfiles || []);
    console.log(`Restored relay store (${alertStore.size} tokens, ${data.savedAt})`);
    return true;
  } catch (e) {
    console.error('Failed to load relay store:', e.message);
    return false;
  }
}

// Load state from disk on startup
loadFromDisk();

// Auto-save periodically
let saveTimer = setInterval(saveToDisk, SAVE_INTERVAL_MS);

const alertRouter = express.Router();

alertRouter.post('/push', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const alert = req.body;
  if (!alertStore.has(token)) alertStore.set(token, []);

  const alerts = alertStore.get(token);
  alerts.push({
    ...alert,
    queue_id: generateId(),
    timestamp: Date.now(),
    id: alert.id || Date.now().toString(),
  });

  if (alerts.length > MAX_STORED_ALERTS) alerts.shift();

  console.log(`Alert relayed: ${alert.app || alert.alertType || 'unknown'} (token: ${token.substring(0, 8)}...)`);

  // Persist immediately for critical alerts
  if (alert.severity === 'critical') saveToDisk();

  res.status(201).json({ success: true, alertCount: alerts.length });
});

alertRouter.get('/poll', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const afterId = req.query.after;
  let alerts = alertStore.get(token) || [];

  // If after_id is provided, only return messages newer than that id
  if (afterId) {
    const idx = alerts.findIndex((a) => a.queue_id === afterId);
    if (idx >= 0) alerts = alerts.slice(idx + 1);
  } else {
    // Clear after poll to prevent duplicates (legacy behavior)
    if (alerts.length > 0) alertStore.set(token, []);
  }

  console.log(`Delivered ${alerts.length} alert(s) to parent (token: ${token.substring(0, 8)}...)`);
  res.json({ alerts });
});

alertRouter.post('/test', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const { app, severity, alertType, childName } = req.body;

  if (!alertStore.has(token)) alertStore.set(token, []);

  const testAlert = {
    app: app || 'WhatsApp',
    severity: severity || 'high',
    alertType: alertType || 'suspicious_content',
    childName: childName || 'Test Child',
    timestamp: new Date().toISOString(),
    id: Date.now().toString(),
    queue_id: generateId(),
    isTestAlert: true,
  };

  alertStore.get(token).push(testAlert);
  console.log(`TEST alert pushed: ${testAlert.app} - ${testAlert.severity} (token: ${token.substring(0, 8)}...)`);
  res.status(201).json({ success: true, alert: testAlert });
});

alertRouter.get('/debug/status', (req, res) => {
  const status = {};
  for (const [token, alerts] of alertStore.entries()) {
    status[token.substring(0, 8) + '...'] = {
      pendingAlerts: alerts.length,
      latestApp: alerts.length > 0 ? alerts[alerts.length - 1].app || 'N/A' : 'none',
    };
  }
  res.json({
    totalTokens: alertStore.size,
    tokens: status,
    historyTokens: historyStore.size,
    profiles: childProfiles.size,
  });
});

const historyRouter = express.Router();

historyRouter.post('/push', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const entry = req.body;
  if (!historyStore.has(token)) historyStore.set(token, []);

  const history = historyStore.get(token);
  history.push({ ...entry, queue_id: generateId(), timestamp: Date.now() });

  if (history.length > MAX_STORED_HISTORY) history.shift();

  console.log(`History relayed: ${entry.url?.substring(0, 50) || 'entry'}`);
  res.status(201).json({ success: true });
});

historyRouter.get('/poll', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const afterId = req.query.after;
  let history = historyStore.get(token) || [];

  if (afterId) {
    const idx = history.findIndex((h) => h.queue_id === afterId);
    if (idx >= 0) history = history.slice(idx + 1);
  } else {
    if (history.length > 0) historyStore.set(token, []);
  }

  res.json({ history });
});

const ackRouter = express.Router();

ackRouter.post('/push', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const ack = req.body;
  if (!ackStore.has(token)) ackStore.set(token, []);

  ackStore.get(token).push({ ...ack, queue_id: generateId(), timestamp: Date.now() });

  console.log(`Ack relayed: ${ack.alertId || 'unknown'}`);
  res.status(201).json({ success: true });
});

ackRouter.get('/poll', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const afterId = req.query.after;
  let acks = ackStore.get(token) || [];

  if (afterId) {
    const idx = acks.findIndex((a) => a.queue_id === afterId);
    if (idx >= 0) acks = acks.slice(idx + 1);
  } else {
    if (acks.length > 0) ackStore.set(token, []);
  }

  res.json({ acks });
});

const childRouter = express.Router();

childRouter.post('/register', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const profile = req.body;
  childProfiles.set(token, { ...profile, registeredAt: Date.now() });

  console.log(`Child registered: ${profile.name || 'Unknown'}`);
  saveToDisk();
  res.status(201).json({ success: true });
});

childRouter.get('/profile', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const profile = childProfiles.get(token);
  if (!profile) return res.status(404).json({ error: 'Profile not found' });

  res.json(profile);
});

const healthRouter = express.Router();

healthRouter.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'relay',
    alerts: alertStore.size,
    history: historyStore.size,
    acks: ackStore.size,
    profiles: childProfiles.size,
  });
});

// Cleanup on termination
process.on('SIGTERM', () => {
  clearInterval(saveTimer);
  saveToDisk();
});
process.on('SIGINT', () => {
  clearInterval(saveTimer);
  saveToDisk();
});

module.exports = {
  alertRouter,
  historyRouter,
  ackRouter,
  childRouter,
  healthRouter,
};
