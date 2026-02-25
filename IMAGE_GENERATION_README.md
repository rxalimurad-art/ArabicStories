# Story Image Generation System

This system automatically generates cover images for all stories using OpenAI's DALL-E 3 and uploads them to Firebase Storage.

## Prerequisites

### 1. OpenAI API Key
You need an OpenAI API key with access to DALL-E 3:
1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Set it as an environment variable:
   ```bash
   export OPENAI_API_KEY='sk-your-key-here'
   ```

### 2. Firebase Service Account
The `serviceAccountKey.json` should already be in your project root.

### 3. Python Dependencies
```bash
pip3 install firebase-admin openai requests pillow
```

## Usage

### Test Mode (Recommended First Step)
Generate just ONE image to test the system:
```bash
export OPENAI_API_KEY='sk-your-key-here'
python3 generate_story_images.py --test
```

### Generate for a Specific Level
Generate images for all 10 stories in Level 1:
```bash
python3 generate_story_images.py --level 1
```

### Generate Batch of Stories
Generate 10 stories starting from index 0:
```bash
python3 generate_story_images.py --start 0 --count 10
```

### Generate ALL Images (500 images!)
⚠️ **Warning**: This will generate 500 images and cost approximately $20 USD (at $0.04 per image).
```bash
python3 generate_story_images.py --all
```

## How It Works

1. **Image Generation**: Uses OpenAI DALL-E 3 to generate 1024x1024 images based on the `imagePrompt` field in each story.

2. **Local Storage**: Saves images locally in `generated_images/` folder.

3. **Firebase Upload**: Uploads images to Firebase Storage at `story_covers/` path.

4. **JSON Update**: Updates `stories.json` with the public Firebase URLs in the `coverImageURL` field.

## Cost Estimation

| Operation | Cost |
|-----------|------|
| Per image (DALL-E 3 standard) | $0.04 |
| 10 stories (1 level) | ~$0.40 |
| 50 stories (5 levels) | ~$2.00 |
| 500 stories (all) | ~$20.00 |

Firebase Storage has its own pricing, but for 500 images (~1MB each), it's negligible for the free tier.

## Troubleshooting

### "OPENAI_API_KEY not set"
Make sure to export your API key before running the script:
```bash
export OPENAI_API_KEY='sk-...'
```

### Firebase Permission Errors
Make sure your service account has Storage Admin permissions.

### Rate Limiting
The script includes built-in delays (1 second between API calls) to respect OpenAI's rate limits.

### Failed Uploads
If Firebase upload fails but image generation succeeds:
1. Images are saved locally in `generated_images/`
2. You can manually upload them via Firebase Console
3. Or re-run the script - it will skip already generated images

## Monitoring Progress

The script:
- Shows progress `[X/Y]` for each story
- Saves progress every 5 stories (so you can resume if interrupted)
- Provides a summary at the end with success/failure counts

## Resuming Interrupted Jobs

If the script stops midway:
1. Check which stories were already processed (they have Firebase URLs in stories.json)
2. Use `--start` with the next index to continue:
   ```bash
   python3 generate_story_images.py --start 15 --count 10
   ```

## Customization

To change image quality or size, edit the `generate_image()` function in `generate_story_images.py`:

```python
response = openai_client.images.generate(
    model="dall-e-3",
    prompt=enhanced_prompt,
    size="1024x1024",  # Options: 1024x1024, 1792x1024, 1024x1792
    quality="standard",  # Options: standard, hd (hd costs more)
    n=1,
)
```
