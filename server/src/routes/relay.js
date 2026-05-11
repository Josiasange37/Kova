// src/routes/relay.js — Temporary message relay for LAN fallback
// Provides store-and-forward for alerts, history, acks when direct LAN fails
const express = require('express');

// In-memory stores (cleared on server restart - use Redis for production)
const alertStore = new Map(); // pairToken -> [alerts]
const historyStore = new Map(); // pairToken -> [history entries]
const ackStore = new Map(); // pairToken -> [acks]
const childProfiles = new Map(); // pairToken -> profile

const MAX_STORED_ALERTS = 100;
const MAX_STORED_HISTORY = 50;

// ── Alert Router ───────────────────────────────────────────────────────────
const alertRouter = express.Router();

alertRouter.post('/push', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const alert = req.body;
  if (!alertStore.has(token)) alertStore.set(token, []);
  
  const alerts = alertStore.get(token);
  alerts.push({ ...alert, timestamp: Date.now(), id: Date.now().toString() });
  
  if (alerts.length > MAX_STORED_ALERTS) alerts.shift();
  
  console.log(`🚨 Alert relayed: ${alert.app || 'unknown'} - ${alert.alertType || 'alert'}`);
  res.status(201).json({ success: true });
});

alertRouter.get('/poll', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const alerts = alertStore.get(token) || [];
  res.json({ alerts });
});

// ── History Router ────────────────────────────────────────────────────────
const historyRouter = express.Router();

historyRouter.post('/push', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const entry = req.body;
  if (!historyStore.has(token)) historyStore.set(token, []);
  
  const history = historyStore.get(token);
  history.push({ ...entry, timestamp: Date.now() });
  
  if (history.length > MAX_STORED_HISTORY) history.shift();
  
  console.log(`📜 History relayed: ${entry.url?.substring(0, 50) || 'entry'}`);
  res.status(201).json({ success: true });
});

historyRouter.get('/poll', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const history = historyStore.get(token) || [];
  res.json({ history });
});

// ── Ack Router ─────────────────────────────────────────────────────────────
const ackRouter = express.Router();

ackRouter.post('/push', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const ack = req.body;
  if (!ackStore.has(token)) ackStore.set(token, []);
  
  ackStore.get(token).push({ ...ack, timestamp: Date.now() });
  
  console.log(`✅ Ack relayed: ${ack.alertId || 'unknown'}`);
  res.status(201).json({ success: true });
});

ackRouter.get('/poll', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const acks = ackStore.get(token) || [];
  res.json({ acks });
});

// ── Child Router ────────────────────────────────────────────────────────────
const childRouter = express.Router();

childRouter.post('/register', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const profile = req.body;
  childProfiles.set(token, { ...profile, registeredAt: Date.now() });
  
  console.log(`👶 Child registered: ${profile.name || 'Unknown'}`);
  res.status(201).json({ success: true });
});

childRouter.get('/profile', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Missing token' });

  const profile = childProfiles.get(token);
  if (!profile) return res.status(404).json({ error: 'Profile not found' });
  
  res.json(profile);
});

// ── Health Check ───────────────────────────────────────────────────────────
const healthRouter = express.Router();

healthRouter.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'relay',
    alerts: alertStore.size,
    history: historyStore.size,
    acks: ackStore.size,
    profiles: childProfiles.size
  });
});

module.exports = {
  alertRouter,
  historyRouter,
  ackRouter,
  childRouter,
  healthRouter
};
