#!/bin/bash

# Script to update package-lock.json and deploy Firebase

echo "🔧 Updating package-lock.json..."
cd functions
npm install

echo ""
echo "📝 Staging changes..."
cd ..
git add .

echo ""
echo "📊 Changed files:"
git status

echo ""
read -p "Ready to commit and push? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "💾 Committing changes..."
    git commit -m "Add email notifications for story and level completions

- Add nodemailer dependency
- Create completion tracking endpoints (story/level)
- Configure email sending to volutiontechnologies@gmail.com
- Add export words button to admin panel
- Update difficulty levels to support 1-400
- Add beautiful HTML email templates"
    
    echo "🚀 Pushing to GitHub..."
    git push
    
    echo ""
    echo "✅ Done! GitHub Actions will deploy automatically."
    echo "📧 Email notifications will be sent to: volutiontechnologies@gmail.com"
else
    echo "❌ Aborted. No changes committed."
fi
