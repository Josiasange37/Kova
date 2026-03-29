# KOVA APK Build - GitHub Actions Workflow Guide

## Overview
The KOVA project is now configured to build the APK automatically on GitHub using GitHub Actions CI/CD.

## Repository Details
- **Repository**: https://github.com/Josiasange37/Kova
- **Branch**: main
- **Latest Commit**: f020de7 - Phase 2-3: Complete integration and Kotlin native implementation

## GitHub Actions Workflows

### 1. **build.yml** - Continuous Integration Build
**Triggers**: Every push to `main` or `master` branch, and on pull requests

**Steps**:
1. Checkout repository
2. Setup Java 17 (Zulu distribution)
3. Setup Flutter (stable channel)
4. Install dependencies (`flutter pub get`)
5. Analyze code (`flutter analyze`)
6. Build Android APK (`flutter build apk --release`)

**Status**: Ready to trigger on next commit

---

### 2. **build-release.yml** - Release Build with Artifact Upload
**Triggers**: Every push to `main` or `master` branch, and on pull requests

**Steps**:
1. Checkout repository
2. Setup Java 17 (Zulu distribution)
3. Setup Flutter (stable channel)
4. Install dependencies (`flutter pub get`)
5. Analyze code (`flutter analyze`)
6. Build Android APK (`flutter build apk --release`)
7. Upload APK as GitHub artifact named `kova-android-apk`

**Artifact Location**: 
- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Available in GitHub Actions "Artifacts" section for each workflow run

---

## Current Build Status

✅ **Last Commit**: f020de7
- **Message**: Phase 2-3: Complete integration and Kotlin native implementation
- **Files Changed**: 49
- **Insertions**: 4,505
- **Deletions**: 1,075

✅ **Build Prerequisites Met**:
- [x] flutter analyze: 53 issues (0 errors)
- [x] All dependencies installed (`flutter pub get`)
- [x] All Kotlin services created and configured
- [x] AndroidManifest.xml updated with permissions
- [x] No breaking changes to existing 32 screens

---

## View Workflow Results

### Option 1: GitHub Web Interface
1. Go to: https://github.com/Josiasange37/Kova
2. Click on "Actions" tab
3. Select the latest workflow run
4. View build logs and download APK from Artifacts

### Option 2: Using GitHub CLI
```bash
# List recent workflow runs
gh run list -R Josiasange37/Kova

# View specific run details
gh run view <RUN_ID> -R Josiasange37/Kova

# Download APK artifact
gh run download <RUN_ID> -R Josiasange37/Kova
```

---

## What Gets Built

**Output APK**: `app-release.apk`

**Includes**:
- Single APK with two modes (parent & child)
- Fully offline SQLite database
- All 32 existing screens preserved
- Kotlin native services:
  - KovaAccessibilityService (message monitoring)
  - KovaForegroundService (background protection)
  - KovaDeviceAdmin (device admin capabilities)
  - KovaBootReceiver (survives reboot)
  - BlockOverlayActivity (app blocking)
- Placeholder AI classifiers (ready for TFLite integration)
- MethodChannel communication between Flutter and Kotlin

**Size**: ~50-60 MB (typical Flutter APK with Kotlin services)

---

## Build Success Criteria

The build is considered successful when:
1. ✅ `flutter pub get` completes without errors
2. ✅ `flutter analyze` passes (warnings are OK)
3. ✅ `flutter build apk --release` completes without errors
4. ✅ APK file is created at `build/app/outputs/flutter-apk/app-release.apk`
5. ✅ APK is uploaded as artifact (build-release.yml only)

---

## Troubleshooting

### If Build Fails:
1. Check the workflow logs on GitHub Actions
2. Common issues:
   - Java version mismatch → Workflow uses Java 17 (Zulu)
   - Flutter version incompatibility → Workflow uses stable channel
   - Kotlin syntax errors → Check recent .kt files
   - Missing resources → Check res/ directory files

### To Debug Locally:
```bash
cd /home/almight/kova
flutter pub get
flutter analyze
flutter build apk --release
```

### Key Build Artifacts Location:
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Logs**: Check GitHub Actions workflow run output

---

## Next Steps

1. **Download APK**: 
   - Go to Actions tab → Select latest run → Download `kova-android-apk` artifact

2. **Test on Device**:
   - Connect Android device
   - `adb install build/app/outputs/flutter-apk/app-release.apk`

3. **Monitor Build**:
   - GitHub Actions will show real-time build progress
   - Email notifications when build completes (success/failure)

4. **Future Improvements**:
   - Add signing configuration for Play Store
   - Add performance testing in workflow
   - Add automated testing
   - Create release tags and changelog

---

## Workflow Configuration Files

**Location**: `.github/workflows/`

- `build.yml` - CI build on every push/PR
- `build-release.yml` - CI build + artifact upload

Both workflows run on: `ubuntu-latest`
Both use: Java 17, Flutter stable, Zulu distribution

---

## Last Updated
- **Commit**: f020de7
- **Date**: 2026-03-29
- **Status**: Ready for GitHub Actions to build

---
