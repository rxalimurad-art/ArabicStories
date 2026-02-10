#!/bin/bash
set -e

echo "🕌 Arabic Stories Admin - Setup"
echo "================================"

# Check if firebase is installed
if ! command -v firebase &> /dev/null; then
    echo "Installing Firebase CLI..."
    npm install -g firebase-tools
fi

# Login if needed
echo ""
echo "Checking Firebase login..."
firebase login

# List projects
echo ""
echo "Your Firebase projects:"
firebase projects:list

echo ""
echo "Select a project to use:"
firebase use --add

# Initialize
echo ""
echo "Initializing Firebase..."
firebase init functions hosting firestore --project $(firebase use)

# Install dependencies
echo ""
echo "Installing dependencies..."
cd functions
npm install
cd ..

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start local development:"
echo "  firebase emulators:start"
echo ""
echo "To deploy:"
echo "  firebase deploy"
