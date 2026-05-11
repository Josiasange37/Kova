// src/index.js — KOVA Backend Entry Point
require('dotenv').config();

const express = require('express');
const http = require('http');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Server } = require('socket.io');

// Relay Routes (in-memory, no DB required)
const pairingRoutes = require('./routes/pairing');
const { alertRouter, historyRouter, ackRouter, childRouter } = require('./routes/relay');

// DB-dependent routes — loaded conditionally
let authRoutes, childrenRoutes, dashboardRoutes, alertsRoutes, appsRoutes, settingsRoutes;
let dbAvailable = false;

try {
  const pool = require('./db/pool');
  // Test if DB is actually reachable (non-blocking)
  pool.query('SELECT 1').then(() => {
    dbAvailable = true;
    console.log('✅ PostgreSQL connected');
  }).catch((err) => {
    console.warn('⚠️  PostgreSQL not available — running in RELAY-ONLY mode');
    console.warn('   (Pairing, alerts relay, and history relay still work)');
  });
  
  authRoutes = require('./routes/auth');
  childrenRoutes = require('./routes/children');
  dashboardRoutes = require('./routes/dashboard');
  alertsRoutes = require('./routes/alerts');
  appsRoutes = require('./routes/apps');
  settingsRoutes = require('./routes/settings');
} catch (err) {
  console.warn('⚠️  DB modules failed to load — running in RELAY-ONLY mode');
}

// Socket
let initSocket;
try {
  initSocket = require('./socket');
} catch (err) {
  console.warn('⚠️  Socket module failed to load');
}

const app = express();
const server = http.createServer(app);

// ── Socket.io setup ──
const io = new Server(server, {
  cors: {
    origin: '*', // Allow Flutter dev connections
    methods: ['GET', 'POST'],
  },
});

// ── Middleware ──
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// ── Health check ──
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'kova-server',
    mode: dbAvailable ? 'full' : 'relay-only',
    timestamp: new Date().toISOString(),
  });
});

// ── DB-dependent API Routes (only if DB available) ──
if (authRoutes) app.use('/api/auth', authRoutes);
if (childrenRoutes) app.use('/api/children', childrenRoutes);
if (dashboardRoutes) app.use('/api/dashboard', dashboardRoutes);
if (alertsRoutes) app.use('/api/alerts', alertsRoutes);
if (appsRoutes) app.use('/api/apps', appsRoutes);
if (settingsRoutes) app.use('/api/settings', settingsRoutes);

// ── Relay Routes (always available — in-memory, no DB needed) ──
app.use('/api/pair', pairingRoutes);
app.use('/api/pairing', pairingRoutes); // alias
app.use('/api/alert', alertRouter);
app.use('/api/history', historyRouter);
app.use('/api/ack', ackRouter);
app.use('/api/child', childRouter);

// ── Serve Frontend (only if build exists locally) ──
const fs = require('fs');
const parentAppPath = path.join(__dirname, '../../build/web');

if (fs.existsSync(parentAppPath)) {
  app.use(express.static(parentAppPath));
}

// ── API 404 handler ──
app.use('/api', (req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// ── Root landing page ──
app.get('/', (req, res) => {
  res.json({
    service: 'KOVA Backend API',
    status: 'online',
    mode: dbAvailable ? 'full' : 'relay-only',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/api/health',
      pair_register: 'POST /api/pair/register',
      pair_claim: 'POST /api/pair/claim',
      pair_status: 'GET /api/pair/status?code=XXX',
      alert_push: 'POST /api/alert/push',
      alert_poll: 'GET /api/alert/poll',
      alert_test: 'POST /api/alert/test',
      alert_debug: 'GET /api/alert/debug/status',
    },
    documentation: 'KOVA child protection API. Relay mode works without PostgreSQL.',
  });
});

// ── Catch-all for unknown routes ──
app.get('*', (req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `No route for ${req.method} ${req.path}. Use /api/* endpoints.`,
  });
});

// ── Global error handler ──
app.use((err, req, res, _next) => {
  console.error('🔥 Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Initialization Logic ──
const PORT = process.env.PORT || 3000;

// Export the app for Vercel
module.exports = app;

// Only start the server if running locally (not on Vercel/Serverless)
if (require.main === module) {
  if (initSocket) {
    try {
      initSocket(io);
    } catch (err) {
      console.warn('⚠️  Socket initialization failed (DB may be unavailable):', err.message);
    }
  }
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`
╔══════════════════════════════════════════════╗
║       🛡️  KOVA Server Running                ║
║                                              ║
║  Mode:      ${dbAvailable ? 'FULL (with DB)     ' : 'RELAY-ONLY (no DB)'}    ║
║  REST API:  http://0.0.0.0:${PORT}/api          ║
║  Socket.io: ws://0.0.0.0:${PORT}                ║
║  Health:    http://0.0.0.0:${PORT}/api/health    ║
║                                              ║
║  📱 Flutter clients: use your local IP       ║
║     e.g. http://192.168.x.x:${PORT}             ║
╚══════════════════════════════════════════════╝
    `);
  });
}
