// src/db/seed.js — Seed demo data matching the Flutter prototype's hardcoded values
require('dotenv').config();
const bcrypt = require('bcryptjs');
const pool = require('./pool');

async function seed() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // ── Parent: "John" from dashboard greeting ──
    const pinHash = await bcrypt.hash('1234', 10);
    const { rows: [parent] } = await client.query(
      `INSERT INTO parents (name, phone, pin_hash)
       VALUES ($1, $2, $3)
       ON CONFLICT (phone) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`,
      ['John', '+1234567890', pinHash]
    );

    // ── Child: "Emma" from dashboard ──
    const { rows: [child] } = await client.query(
      `INSERT INTO children (parent_id, name, age, safety_score, is_online)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [parent.id, 'Emma', 10, 95, true]
    );

    // ── Pairing code (matches hardcoded KOVA-7X4Q-9N2P) ──
    await client.query(
      `INSERT INTO pairing_codes (parent_id, child_id, code, status, expires_at)
       VALUES ($1, $2, $3, $4, NOW() + INTERVAL '24 hours')`,
      [parent.id, child.id, 'KOVA-7X4Q-9N2P', 'connected']
    );

    // ── Monitored apps (from MonitoredAppsScreen) ──
    const apps = [
      { name: 'WhatsApp',  pkg: 'com.whatsapp',          type: 'connected',  connected: true,  icon: 'chat_rounded',         color: '#25D366' },
      { name: 'TikTok',    pkg: 'com.zhiliaoapp.musically', type: 'automatic', connected: false, icon: 'music_note_rounded',   color: '#010101' },
      { name: 'Facebook',  pkg: 'com.facebook.katana',   type: 'automatic',  connected: false, icon: 'facebook_rounded',     color: '#1877F2' },
      { name: 'Instagram', pkg: 'com.instagram.android', type: 'automatic',  connected: false, icon: 'camera_alt_rounded',   color: '#E4405F' },
      { name: 'SMS',       pkg: 'com.android.mms',       type: 'automatic',  connected: false, icon: 'sms_rounded',          color: '#7C4DFF' },
    ];

    for (const app of apps) {
      await client.query(
        `INSERT INTO monitored_apps (child_id, app_name, package_name, monitoring_type, is_connected, icon_name, icon_color)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (child_id, app_name) DO NOTHING`,
        [child.id, app.name, app.pkg, app.type, app.connected, app.icon, app.color]
      );
    }

    // ── App controls ──
    const controls = [
      { name: 'WhatsApp',  sensitivity: 'high',   blocked: false, enabled: true },
      { name: 'TikTok',    sensitivity: 'medium', blocked: false, enabled: true },
      { name: 'Facebook',  sensitivity: 'medium', blocked: false, enabled: true },
      { name: 'Instagram', sensitivity: 'medium', blocked: false, enabled: true },
      { name: 'SMS',       sensitivity: 'low',    blocked: false, enabled: true },
    ];

    for (const ctrl of controls) {
      await client.query(
        `INSERT INTO app_controls (child_id, app_name, sensitivity, is_blocked, is_enabled)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (child_id, app_name) DO NOTHING`,
        [child.id, ctrl.name, ctrl.sensitivity, ctrl.blocked, ctrl.enabled]
      );
    }

    // ── Sample alerts (match AlertHistoryScreen / AlertDetailScreen data) ──
    const alerts = [
      {
        app: 'WhatsApp', type: 'cyberbullying', severity: 'high',
        sender: 'Unknown Contact', content: 'Hey kid, wanna come over? I have candy...',
        confidence: 94.5, resolved: false,
      },
      {
        app: 'Instagram', type: 'explicit', severity: 'medium',
        sender: '@dark_user_42', content: 'Inappropriate image detected in DM',
        confidence: 87.2, resolved: false,
      },
      {
        app: 'TikTok', type: 'violence', severity: 'low',
        sender: 'For You Feed', content: 'Violent content detected in video recommendation',
        confidence: 72.8, resolved: true,
      },
    ];

    for (const alert of alerts) {
      await client.query(
        `INSERT INTO alerts (child_id, app_name, alert_type, severity, sender_info, content_preview, ai_confidence, is_resolved)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [child.id, alert.app, alert.type, alert.severity, alert.sender, alert.content, alert.confidence, alert.resolved]
      );
    }

    // ── Settings ──
    await client.query(
      `INSERT INTO settings (parent_id, quiet_hours_enabled, quiet_hours_start, quiet_hours_end, language)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (parent_id) DO NOTHING`,
      [parent.id, false, '22:00', '07:00', 'en']
    );

    await client.query('COMMIT');
    console.log('✅  Seed data inserted successfully');
    console.log(`   Parent ID: ${parent.id}`);
    console.log(`   Child ID:  ${child.id}`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌  Seed failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
