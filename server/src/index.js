// src/index.js — KOVA Backend Entry Point
require('dotenv').config();

const express = require('express');
const http = require('http');
const path = require('path');
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

// ── Serve Frontend Apps ──
const childAppPath = path.join(__dirname, '../../kovachild/build/web');
const parentAppPath = path.join(__dirname, '../../build/web');

// Serve Child App at /child
app.use('/child', express.static(childAppPath));
app.get('/child/*', (req, res) => {
  res.sendFile(path.join(childAppPath, 'index.html'));
});

// Serve Parent App at /
app.use(express.static(parentAppPath));

// ── API 404 handler ──
app.use('/api', (req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// ── Fallback for Parent App SPA routing ──
app.get('*', (req, res) => {
  const indexPath = path.join(parentAppPath, 'index.html');
  if (require('fs').existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.status(404).json({ 
      error: 'Frontend not found', 
      message: 'The Parent App build folder is missing on this server instance.' 
    });
  }
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
  initSocket(io);
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
}
