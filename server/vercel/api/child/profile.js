// api/child/profile.js — Child retrieves its own profile from relay
const { activePairs, pendingChildProfiles } = require('../_store');

module.exports = (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

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

  const { childDeviceId } = pairData;

  // Look up child profile by childDeviceId
  const profilesForPair = pendingChildProfiles.get(pairToken);
  if (!profilesForPair) {
    return res.status(404).json({ 
      error: 'No child profile found',
      message: 'Parent has not registered a profile yet'
    });
  }

  const profile = profilesForPair.get(childDeviceId);
  if (!profile) {
    return res.status(404).json({ 
      error: 'No child profile found for this device',
      message: 'Parent has not registered a profile yet'
    });
  }

  console.log(`👤 Child profile retrieved for device ${childDeviceId}: ${profile.name}`);

  res.json({
    success: true,
    profile: {
      childId: profile.childId,
      name: profile.name,
      age: profile.age,
      avatarUrl: profile.avatarUrl,
      settings: profile.settings,
      encryptedData: profile.encryptedData,
      iv: profile.iv,
      updatedAt: profile.updatedAt,
    },
  });
};
