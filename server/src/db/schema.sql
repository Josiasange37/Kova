-- KOVA Database Schema
-- PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════
-- Parents table (from ParentProfileScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS parents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) UNIQUE NOT NULL,
  pin_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════
-- Children table (from ChildProfileScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS children (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  age INTEGER NOT NULL CHECK (age >= 1 AND age <= 18),
  safety_score INTEGER DEFAULT 95 CHECK (safety_score >= 0 AND safety_score <= 100),
  is_online BOOLEAN DEFAULT false,
  device_id VARCHAR(255),
  last_seen TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════
-- Pairing codes (from WhatsappConnectScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS pairing_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  code VARCHAR(20) UNIQUE NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'connected', 'expired')),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════
-- Monitored apps (from MonitoredAppsScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS monitored_apps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  app_name VARCHAR(100) NOT NULL,
  package_name VARCHAR(200),
  monitoring_type VARCHAR(20) DEFAULT 'automatic' CHECK (monitoring_type IN ('connected', 'automatic')),
  is_connected BOOLEAN DEFAULT false,
  icon_name VARCHAR(50),
  icon_color VARCHAR(10),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(child_id, app_name)
);

-- ═══════════════════════════════════
-- Alerts (from AlertHistoryScreen + AlertDetailScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  app_name VARCHAR(100) NOT NULL,
  alert_type VARCHAR(50) NOT NULL CHECK (alert_type IN ('cyberbullying', 'predator', 'explicit', 'self_harm', 'violence', 'drugs', 'other')),
  severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  sender_info VARCHAR(200),
  content_preview TEXT,
  ai_confidence DECIMAL(5,2) CHECK (ai_confidence >= 0 AND ai_confidence <= 100),
  is_resolved BOOLEAN DEFAULT false,
  resolved_action VARCHAR(20) CHECK (resolved_action IN ('dismissed', 'blocked', 'reported')),
  resolved_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_alerts_child_id ON alerts(child_id);
CREATE INDEX idx_alerts_created_at ON alerts(created_at DESC);
CREATE INDEX idx_alerts_severity ON alerts(severity);

-- ═══════════════════════════════════
-- App controls (from AppControlScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS app_controls (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  app_name VARCHAR(100) NOT NULL,
  sensitivity VARCHAR(20) DEFAULT 'medium' CHECK (sensitivity IN ('low', 'medium', 'high')),
  is_blocked BOOLEAN DEFAULT false,
  is_enabled BOOLEAN DEFAULT true,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(child_id, app_name)
);

-- ═══════════════════════════════════
-- Settings (from SettingsScreen)
-- ═══════════════════════════════════
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID UNIQUE NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  quiet_hours_enabled BOOLEAN DEFAULT false,
  quiet_hours_start TIME DEFAULT '22:00',
  quiet_hours_end TIME DEFAULT '07:00',
  language VARCHAR(10) DEFAULT 'en',
  notifications_enabled BOOLEAN DEFAULT true,
  weekly_report_enabled BOOLEAN DEFAULT true,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
