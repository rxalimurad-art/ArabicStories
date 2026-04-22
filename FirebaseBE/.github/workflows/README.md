# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the Arabic Stories Firebase project.

## 📋 Workflows Overview

### 1. `ci.yml` - Continuous Integration
**Trigger**: Push to main/master/develop, PRs to main/master

**Purpose**: Validates code quality, security, and PWA requirements

**Features**:
- ✅ Validates Firebase configuration
- ✅ Tests Arabic Stories PWA structure
- ✅ Validates Hifz PWA (if exists)
- ✅ Runs security scans
- ✅ Checks PWA requirements
- ✅ Validates Firestore rules

### 2. `deploy.yml` - Production Deployment
**Trigger**: Push to main/master

**Purpose**: Deploys applications to Firebase Hosting

**Features**:
- 🚀 Deploys Arabic Stories PWA to `qasas-un-nabiyeen.web.app`
- 🚀 Deploys Hifz PWA to `hifz-memorization.web.app` (if available)
- 📦 Builds and deploys Firebase Functions
- 📊 Reports deployment status

### 3. `preview.yml` - Preview Deployment
**Trigger**: Pull Requests

**Purpose**: Creates preview deployments for testing

**Features**:
- 🔍 Deploys PR previews to Firebase Hosting
- 💬 Comments preview URLs on PRs
- 🧪 Includes testing checklist
- 🔄 Updates existing comments

## 🔧 Setup Requirements

### GitHub Secrets
Add these secrets to your repository:

1. **`FIREBASE_SERVICE_ACCOUNT_ARABICSTORIES_82611`**
   ```bash
   # Generate service account key
   firebase projects:list
   firebase use arabicstories-82611
   
   # Go to Firebase Console > Project Settings > Service Accounts
   # Generate new private key and add JSON content to this secret
   ```

### Firebase Project Configuration
Ensure your `.firebaserc` and `firebase.json` are properly configured:

- **Project**: `arabicstories-82611`
- **Hosting Targets**:
  - `qasas-stories` → `qasas-un-nabiyeen.web.app`
  - `hifz-app` → `hifz-memorization.web.app`

## 📱 PWA Validation

The CI workflow validates:
- Required PWA files (manifest.json, service worker)
- Manifest.json structure
- Service worker registration
- Arabic content presence
- Security best practices

## 🔐 Security Checks

Automated security validation includes:
- Hardcoded secrets detection
- HTTP vs HTTPS URL checking
- Firestore rules validation
- Code quality checks

## 🚀 Deployment Process

### Automatic Deployment
1. **PR Created** → Preview deployment + validation
2. **PR Merged to main** → Production deployment
3. **Push to main** → Production deployment

### Manual Deployment
```bash
# Deploy Arabic Stories only
firebase deploy --only hosting:qasas-stories

# Deploy all targets
firebase deploy --only hosting

# Deploy with functions
firebase deploy
```

## 📊 Monitoring

Monitor deployments via:
- GitHub Actions tab
- Firebase Console
- Live URLs:
  - https://qasas-un-nabiyeen.web.app
  - https://hifz-memorization.web.app

## 🛠 Troubleshooting

### Common Issues

1. **Service Account Permission Error**
   - Verify `FIREBASE_SERVICE_ACCOUNT_ARABICSTORIES_82611` secret
   - Ensure service account has Firebase Hosting Admin role

2. **Hosting Target Not Found**
   - Run: `firebase hosting:sites:create <site-name>`
   - Update `.firebaserc` with correct targets

3. **Build Failures**
   - Check Node.js version compatibility (uses Node 18)
   - Verify all dependencies in package.json
   - Ensure build scripts work locally

### Debug Commands
```bash
# Validate configuration locally
firebase projects:list
firebase hosting:sites:list
firebase use arabicstories-82611

# Test local deployment
firebase serve --only hosting:qasas-stories
firebase serve --only hosting:hifz-app
```