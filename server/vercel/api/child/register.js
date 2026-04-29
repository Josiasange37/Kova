// api/child/register.js — Parent pushes child profile to relay for child retrieval
const { activePairs, pendingChildProfiles } = require('../_store');

const JWT_SECRET = process.env.JWT_SECRET || 'kova-relay-secret-change-in-production';

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Extract pairToken from Authorization header
  const authHeader = req.headers['authorization'] || req.headers['Authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  const pairToken = authHeader.substring(7);

  // Validate pairToken exists
  const pairData = activePairs.get(pairToken);
  if (!pairData) {
    return res.status(401).json({ error: 'Invalid or expired pair token' });
  }

  const { childDeviceId, parentDeviceId } = pairData;

  // Parse child profile from body
  const { 
    childId, 
    name, 
    age, 
    avatarUrl, 
    settings,
    encryptedData,  // AES-encrypted payload for end-to-end encryption
    iv             // Initialization vector for decryption
  } = req.body || {};

  if (!childId || !name) {
    return res.status(400).json({ error: 'childId and name are required' });
  }

  // Store child profile keyed by childDeviceId so child can retrieve it
  const profile = {
    childId,
    parentDeviceId,
    childDeviceId,
    name,
    age: age || 10,
    avatarUrl: avatarUrl || null,
    settings: settings || {},
    encryptedData: encryptedData || null,
    iv: iv || null,
    updatedAt: Date.now(),
  };

  // Initialize storage for this pair if needed
  if (!pendingChildProfiles.has(pairToken)) {
    pendingChildProfiles.set(pairToken, new Map());
  }
  
  // Store profile - child will poll for this
  pendingChildProfiles.get(pairToken).set(childDeviceId, profile);

  console.log(`👤 Child profile registered: ${name} (${childId}) for device ${childDeviceId}`);

  res.json({
    success: true,
    message: 'Child profile registered successfully',
    childId,
    timestamp: profile.updatedAt,
  });
};
