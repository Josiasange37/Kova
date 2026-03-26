// src/index.js — KOVA Backend Entry Point
require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Server } = require('socket.io');

// Routes
const authRoutes = require('./routes/auth');
const childrenRoutes = require('./routes/children');
const pairingRoutes = require('./routes/pairing');
const dashboardRoutes = require('./routes/dashboard');
const alertsRoutes = require('./routes/alerts');
const appsRoutes = require('./routes/apps');
const settingsRoutes = require('./routes/settings');

// Socket
const initSocket = require('./socket');

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
    timestamp: new Date().toISOString(),
  });
});

// ── API Routes ──
app.use('/api/auth', authRoutes);
app.use('/api/children', childrenRoutes);
app.use('/api/pairing', pairingRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/alerts', alertsRoutes);
app.use('/api/apps', appsRoutes);
app.use('/api/settings', settingsRoutes);

// ── 404 handler ──
app.use((req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// ── Global error handler ──
app.use((err, req, res, _next) => {
  console.error('🔥 Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Initialize Socket.io ──
initSocket(io);

// ── Start server ──
const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log(`
╔══════════════════════════════════════════╗
║       🛡️  KOVA Server Running            ║
║                                          ║
║  REST API:  http://localhost:${PORT}/api    ║
║  Socket.io: ws://localhost:${PORT}          ║
║  Health:    http://localhost:${PORT}/api/health ║
╚══════════════════════════════════════════╝
  `);
});

// Export for testing
module.exports = { app, server, io };
