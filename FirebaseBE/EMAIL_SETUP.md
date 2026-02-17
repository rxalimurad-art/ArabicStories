# Email Notification Setup Guide

## Overview
This system sends email notifications to `volutiontechnologies@gmail.com` when users:
- Complete a story
- Complete a level

## Setup Instructions

### 1. Create Gmail App Password

1. Go to your Google Account: https://myaccount.google.com/
2. Navigate to **Security**
3. Enable **2-Step Verification** (if not already enabled)
4. Go to **App passwords** (search for it in settings)
5. Create a new app password:
   - App: Mail
   - Device: Other (Custom name) → "Arabic Stories Firebase"
6. Copy the 16-character password (save it securely)

### 2. Configure Firebase Functions

#### Option A: Using Firebase CLI (Recommended for Production)

```bash
cd FirebaseBE/functions

# Set email credentials
firebase functions:config:set email.user="your-gmail@gmail.com"
firebase functions:config:set email.pass="your-16-char-app-password"

# View current config
firebase functions:config:get

# Deploy with new config
firebase deploy --only functions
```

#### Option B: Using Environment Variables (Local Development)

Create `.env` file in `functions/` directory:

```bash
EMAIL_USER=your-gmail@gmail.com
EMAIL_PASSWORD=your-16-char-app-password
```

**Important:** Add `.env` to `.gitignore` to prevent committing credentials!

### 3. Install Dependencies

```bash
cd FirebaseBE/functions
npm install
```

### 4. Deploy

```bash
firebase deploy --only functions
```

## API Endpoints

### 1. Track Story Completion

**POST** `/api/completions/story`

**Request Body:**
```json
{
  "userId": "user123",
  "userName": "Ahmed Ali",
  "userEmail": "ahmed@example.com",
  "storyId": "story-uuid",
  "storyTitle": "The Friendly Cat",
  "difficultyLevel": 5
}
```

**Response:**
```json
{
  "success": true,
  "message": "Story completion tracked",
  "completionId": "completion-doc-id",
  "emailSent": true
}
```

### 2. Track Level Completion

**POST** `/api/completions/level`

**Request Body:**
```json
{
  "userId": "user123",
  "userName": "Ahmed Ali",
  "userEmail": "ahmed@example.com",
  "level": 10
}
```

**Response:**
```json
{
  "success": true,
  "message": "Level completion tracked",
  "completionId": "completion-doc-id",
  "emailSent": true
}
```

### 3. Get User Completions

**GET** `/api/completions?userId=user123&type=story&limit=50`

**Query Parameters:**
- `userId` (optional): Filter by user ID
- `type` (optional): Filter by type (`story` or `level`)
- `limit` (optional): Number of results (default: 50)

**Response:**
```json
{
  "success": true,
  "count": 10,
  "completions": [
    {
      "id": "completion-id",
      "type": "story",
      "userId": "user123",
      "userName": "Ahmed Ali",
      "storyTitle": "The Friendly Cat",
      "difficultyLevel": 5,
      "completedAt": "2024-01-15T10:30:00.000Z",
      "notificationSent": true
    }
  ]
}
```

## iOS App Integration

### Swift Example

```swift
import Foundation

struct CompletionService {
    static let baseURL = "https://your-project.web.app/api"
    
    // Track story completion
    static func trackStoryCompletion(
        userId: String,
        userName: String,
        userEmail: String?,
        storyId: String,
        storyTitle: String,
        difficultyLevel: Int
    ) async throws {
        let url = URL(string: "\(baseURL)/completions/story")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "userEmail": userEmail ?? "",
            "storyId": storyId,
            "storyTitle": storyTitle,
            "difficultyLevel": difficultyLevel
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Track level completion
    static func trackLevelCompletion(
        userId: String,
        userName: String,
        userEmail: String?,
        level: Int
    ) async throws {
        let url = URL(string: "\(baseURL)/completions/level")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "userEmail": userEmail ?? "",
            "level": level
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
    }
}
```

### Usage Example

```swift
// When user completes a story
Task {
    try await CompletionService.trackStoryCompletion(
        userId: Auth.auth().currentUser?.uid ?? "unknown",
        userName: user.displayName ?? "Unknown",
        userEmail: user.email,
        storyId: story.id,
        storyTitle: story.title,
        difficultyLevel: story.difficultyLevel
    )
}

// When user completes a level
Task {
    try await CompletionService.trackLevelCompletion(
        userId: Auth.auth().currentUser?.uid ?? "unknown",
        userName: user.displayName ?? "Unknown",
        userEmail: user.email,
        level: completedLevel
    )
}
```

## Email Templates

### Story Completion Email
- Subject: `📚 Story Completed: [Story Title] (Level [X])`
- Includes: Story name, level, user details, completion timestamp

### Level Completion Email
- Subject: `🏆 Level [X] Completed by [User Name]`
- Includes: Level number, user details, completion timestamp

## Firestore Collection

All completions are stored in the `user_completions` collection:

```
user_completions/
  └── {completionId}
      ├── type: "story" | "level"
      ├── userId: string
      ├── userName: string
      ├── userEmail: string | null
      ├── storyId: string (for story completions)
      ├── storyTitle: string (for story completions)
      ├── difficultyLevel: number (for story completions)
      ├── level: number (for level completions)
      ├── completedAt: timestamp
      └── notificationSent: boolean
```

## Troubleshooting

### Email not sending

1. **Check credentials:**
   ```bash
   firebase functions:config:get
   ```

2. **Check function logs:**
   ```bash
   firebase functions:log
   ```

3. **Verify Gmail settings:**
   - 2-Step Verification enabled
   - App password created correctly
   - No spaces in app password

4. **Test locally:**
   ```bash
   firebase emulators:start
   ```

### "Email transporter not configured" warning

This means email credentials are not set. Follow setup instructions above.

### Gmail blocking the login

- Use App Password, not regular password
- Check if "Less secure app access" needs to be enabled (not recommended, use App Password instead)
- Verify the email in Gmail settings

## Security Notes

- Never commit email credentials to Git
- Use Firebase Functions config for production
- Use environment variables for local development
- Add `.env` to `.gitignore`
- Regularly rotate app passwords
- Monitor email usage to prevent abuse

## Production Checklist

- [ ] Gmail App Password created
- [ ] Firebase Functions config set
- [ ] Dependencies installed (`nodemailer`)
- [ ] Functions deployed
- [ ] Test story completion endpoint
- [ ] Test level completion endpoint
- [ ] Verify emails are received
- [ ] iOS app integrated
- [ ] Firestore rules updated (if needed)
