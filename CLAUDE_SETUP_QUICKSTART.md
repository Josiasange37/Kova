# 🚀 CLAUDE SUPER AI - Quick Start for KOVA

Get your Claude AI assistant fully configured for KOVA development in 15 minutes.

---

## STEP 1: Create Claude Project (2 minutes)

Go to [claude.ai](https://claude.ai) and:

1. Click **Projects** → **Create Project**
2. Name: `KOVA Development`
3. Upload these files:
   - ✅ `SKILL.md` (complete codebase knowledge)
   - ✅ `CLAUDE.md` (quick reference)
   - ✅ `pubspec.yaml` (dependencies)
   - ✅ Any design images/mockups

4. Add custom instructions:
   ```
   You are an expert Flutter/Android developer specializing in parental control apps.
   Always check SKILL.md before answering questions about KOVA architecture.
   When suggesting code changes:
   1. Add error handling with try-catch
   2. Check for null safety (no ! without null check)
   3. Consider MIUI/Xiaomi compatibility
   4. Use debugPrint with descriptive emojis (✅, ❌, ⚠️)
   Never suggest code that could crash the child safety features.
   ```

---

## STEP 2: Install Claude Code (3 minutes)

### Terminal Installation:

```bash
# macOS
brew install claude-code

# Or universal installer
curl -fsSL https://claude.ai/install | bash

# Verify
claude --version
```

### Start Using:

```bash
# Navigate to your project
cd /home/almight/Kova

# Start Claude Code
claude

# Claude automatically reads CLAUDE.md!
```

---

## STEP 3: Essential Commands Cheat Sheet

### Navigation & Context:
```bash
/help              # Show all commands
/cost              # Check token usage
/clear             # Clear conversation
/compact           # Compress context (save tokens)
/exit              # Quit Claude
```

### File Operations:
```bash
"Read lib/child/services/detection_orchestrator.dart"
"Edit the safeBlockApp method to add logging"
"Create new file lib/shared/services/analytics_service.dart"
"Search for all uses of MethodChannel"
"Find files that import monitoring_bridge.dart"
```

### Code Actions:
```bash
"Run flutter analyze and fix all errors"
"Build APK and check for warnings"
"Add error handling to all native calls in accessibility_bridge.dart"
"Rename _safeBlockApp to safeBlockApp in all files"
"Generate unit tests for detection_orchestrator.dart"
```

### Git Integration:
```bash
"Show git status"
"Commit all with message 'Fix overlay crash'"
"Create branch feature/time-limits"
"Show diff of last commit"
"Push to origin main"
```

---

## STEP 4: MCP Setup (Optional - 5 minutes)

### Create Config File:

```bash
# Create config directory
mkdir -p ~/.config/claude

# Create config file
nano ~/.config/claude/mcp.json
```

### Add MCP Servers:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/almight/Kova"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token_here"
      }
    }
  }
}
```

### Get GitHub Token:

1. Go to GitHub → Settings → Developer Settings → Personal Access Tokens
2. Generate new token (classic)
3. Scopes: `repo`, `read:org`
4. Copy token to config

---

## STEP 5: VS Code Integration (Optional - 3 minutes)

### Install Extension:

1. Open VS Code
2. Extensions → Search "Claude"
3. Install "Claude for VS Code"
4. Restart VS Code

### Configure:

```json
// settings.json
{
  "claude.apiKey": "sk-ant-your-api-key",
  "claude.preferredModel": "claude-3-5-sonnet-20241022",
  "claude.codeActions.enabled": true,
  "claude.inlineCompletions.enabled": true
}
```

### Get API Key:

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Create API key
3. Copy to VS Code settings

---

## STEP 6: Create Custom Skill (Optional - 2 minutes)

Create `.claude/skills/kova-expert.md`:

```markdown
---
name: kova-expert
description: KOVA app development expert
---

## Expertise
- Flutter/Android development
- Parental control app architecture  
- Real-time safety systems
- MIUI/Xiaomi compatibility
- On-device AI (TensorFlow Lite)

## Code Standards
- Always add error handling
- Never use ! without null check
- Test on real device, not emulator
- Consider battery optimization
- Log with emojis (✅ ❌ ⚠️)

## File Locations
- Detection: lib/child/services/detection_orchestrator.dart
- Bridge: lib/child/services/monitoring_bridge.dart
- Network: lib/shared/services/network_sync_service.dart
- Database: lib/local_backend/database/database_service.dart
```

---

## 🎯 DAILY WORKFLOW

### Morning:
```bash
cd /home/almight/Kova
claude

"Good morning! Read CLAUDE.md for today's context."
"What tasks should I prioritize for KOVA today?"
```

### During Development:
```bash
"I'm adding time limit feature. 
Show me where app blocking is implemented."

"Add the feature with proper error handling."

"Test the implementation."
```

### Before Commit:
```bash
"Run flutter analyze"
"Fix any issues found"
"Check git status"
"Commit with descriptive message"
```

### Evening:
```bash
/cost
"Show me what we accomplished today"
/save  # Save conversation
/exit
```

---

## 💡 POWER USER TIPS

### 1. Save Token Usage:
```bash
# Use /compact regularly
/compact

# Clear when switching tasks
/clear

# Only load needed files
"Read detection_orchestrator.dart only"
```

### 2. Effective Prompting:
```bash
# Good prompts:
"Add retry logic to safeBlockApp with exponential backoff"
"Find all null pointer risks in the codebase"
"Create test for the overlay blocking feature"

# Bad prompts:
"Fix the app"
"Make it better"
"Do stuff"
```

### 3. Context Management:
```bash
# Check what's loaded
"What files are in your current context?"

# Add specific context
"Also read monitoring_bridge.dart"

# Clear everything
/clear
```

### 4. Verification:
```bash
# Always verify critical changes:
"Will this work on MIUI phones?"
"Did you add error handling?"
"Is there a null check before the bang operator?"
"Can this crash the child app?"
```

---

## 🐛 TROUBLESHOOTING

### Claude not reading files?
```bash
# In Claude Code:
"Read /home/almight/Kova/SKILL.md"

# Or use absolute path:
"Read file:///home/almight/Kova/SKILL.md"
```

### Context too full?
```bash
/compact
# or
/clear
```

### Token usage too high?
```bash
/cost
# Then:
/compact
# and avoid loading entire lib/ directory
```

### Claude not understanding KOVA?
```bash
# Remind it:
"Check SKILL.md for KOVA architecture"
"Look at CLAUDE.md for quick reference"
"Remember this is a parental control app with child/parent modes"
```

---

## 📊 COST TRACKING

### Free Tier Limits:
- **Claude.ai Projects**: Unlimited (with rate limits)
- **Claude Code**: Uses your API account
- **API Pricing** (Claude 3.5 Sonnet):
  - Input: $3 per million tokens
  - Output: $15 per million tokens
  - ~$0.01-0.05 per typical coding session

### Cost Optimization:
- ✅ Use `/compact` regularly
- ✅ Use Projects (cheaper than API)
- ✅ Clear context between tasks
- ✅ Don't load entire codebase

### With $100 Credit:
- Can use Claude Code heavily for months
- Typical session: ~500-2000 tokens
- 100 sessions = ~$5
- 2000 sessions = $100

---

## 🎓 LEARNING PATH

### Week 1: Basics
- [ ] Create Claude Project
- [ ] Install Claude Code
- [ ] Learn basic commands
- [ ] Practice file operations

### Week 2: Advanced
- [ ] Use /compact and /cost
- [ ] Try multi-file edits
- [ ] Set up MCP (optional)
- [ ] Create custom skill

### Week 3: Power User
- [ ] Use chain-of-thought prompting
- [ ] Master context management
- [ ] Automate workflows
- [ ] Integrate with GitHub

### Week 4: Expert
- [ ] Build complex features with Claude
- [ ] Debug production issues
- [ ] Review code at scale
- [ ] Train team members

---

## ✅ CHECKLIST - ARE YOU SET UP?

- [ ] Claude Project created with KOVA name
- [ ] SKILL.md uploaded to Project
- [ ] CLAUDE.md uploaded to Project
- [ ] Custom instructions added
- [ ] Claude Code installed in terminal
- [ ] Tested with: "Analyze detection_orchestrator.dart"
- [ ] Can run: flutter analyze, git commit, etc.
- [ ] Understand /cost, /clear, /compact commands
- [ ] Know how to load specific files
- [ ] Can ask context-aware questions

---

## 🚀 YOU'RE READY!

**Your Claude is now a SUPER AI for KOVA development.**

**Next steps:**
1. Test it: "What is the detection flow in KOVA?"
2. Build something: "Add logging to safeBlockApp"
3. Debug: "Why might overlay crash on Xiaomi?"
4. Scale: "Review all error handling in the codebase"

**Happy coding with your AI super-coworker!** 🎉

---

*Quick Start Guide - KOVA Development*
*For: Claude AI Assistant Setup*
