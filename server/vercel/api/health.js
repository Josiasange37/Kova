// api/health.js — Health check endpoint
module.exports = (req, res) => {
  res.json({
    status: 'ok',
    service: 'kova-relay',
    timestamp: new Date().toISOString(),
  });
};
