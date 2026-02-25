#!/usr/bin/env python3
"""
Story Image Generator and Firebase Uploader

This script:
1. Generates images using OpenAI's DALL-E 3 based on story prompts
2. Uploads generated images to Firebase Storage
3. Updates stories.json with the image URLs

Requirements:
- OpenAI API key (set in OPENAI_API_KEY environment variable)
- Firebase service account key (serviceAccountKey.json)
- Python packages: firebase-admin, openai, requests, pillow

Usage:
    # Test with first story only
    python3 generate_story_images.py --test
    
    # Generate for specific level
    python3 generate_story_images.py --level 1
    
    # Generate for all stories (500 images - expensive!)
    python3 generate_story_images.py --all
    
    # Generate batch of 10 stories starting from index
    python3 generate_story_images.py --start 0 --count 10
"""

import json
import os
import sys
import time
import argparse
from datetime import datetime
from pathlib import Path

# Third-party imports
import firebase_admin
from firebase_admin import credentials, storage
from openai import OpenAI

# Configuration
FIREBASE_STORAGE_BUCKET = "arabicstories-82611.firebasestorage.app"
SERVICE_ACCOUNT_PATH = "serviceAccountKey.json"
STORIES_JSON_PATH = "ArabicStories/OfflineBundle/stories.json"
IMAGES_DIR = "generated_images"


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred, {
        'storageBucket': FIREBASE_STORAGE_BUCKET
    })
    return storage.bucket()


def initialize_openai():
    """Initialize OpenAI client."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("❌ Error: OPENAI_API_KEY environment variable not set!")
        print("   Get your API key from: https://platform.openai.com/api-keys")
        print("   Then run: export OPENAI_API_KEY='your-key-here'")
        sys.exit(1)
    return OpenAI(api_key=api_key)


def generate_image(openai_client, prompt, story_title, output_path):
    """Generate image using DALL-E 3."""
    # Enhance the prompt for better children's book illustration quality
    enhanced_prompt = f"""
{prompt}

Style: Children's picture book illustration, warm and inviting, soft lighting, 
detailed but not overwhelming, suitable for young readers, family-friendly atmosphere.
"""
    
    print(f"   🎨 Generating image for: {story_title[:40]}...")
    
    try:
        response = openai_client.images.generate(
            model="dall-e-3",
            prompt=enhanced_prompt,
            size="1024x1024",  # DALL-E 3 supports 1024x1024, 1792x1024, 1024x1792
            quality="standard",
            n=1,
        )
        
        image_url = response.data[0].url
        
        # Download the image
        import requests
        img_response = requests.get(image_url)
        img_response.raise_for_status()
        
        # Save locally
        with open(output_path, 'wb') as f:
            f.write(img_response.content)
        
        print(f"   ✅ Image saved: {output_path}")
        return output_path
        
    except Exception as e:
        print(f"   ❌ Error generating image: {e}")
        return None


def upload_to_firebase(bucket, local_path, remote_path):
    """Upload image to Firebase Storage and return public URL."""
    try:
        blob = bucket.blob(remote_path)
        blob.upload_from_filename(local_path)
        
        # Make the blob publicly accessible
        blob.make_public()
        
        print(f"   ✅ Uploaded to Firebase: {blob.public_url}")
        return blob.public_url
        
    except Exception as e:
        print(f"   ❌ Error uploading to Firebase: {e}")
        return None


def process_story(openai_client, bucket, story, story_index, images_dir):
    """Process a single story: generate image and upload."""
    story_id = story['id']
    title = story['title']
    prompt = story.get('imagePrompt', '')
    
    if not prompt:
        print(f"⚠️  Story {story_index}: No image prompt found for '{title}'")
        return None
    
    # Check if already has a cover image URL
    existing_url = story.get('coverImageURL', '')
    if existing_url and 'firebasestorage' in existing_url:
        print(f"⏭️  Story {story_index}: Already has Firebase image, skipping '{title[:40]}...'")
        return existing_url
    
    print(f"\n📖 Story {story_index}: {title}")
    
    # Generate local filename
    safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).rstrip()
    safe_title = safe_title.replace(' ', '_')[:50]
    local_filename = f"story_{story_index:03d}_{safe_title}.png"
    local_path = os.path.join(images_dir, local_filename)
    
    # Skip if already downloaded
    if os.path.exists(local_path):
        print(f"   📁 Image already exists locally")
    else:
        # Generate image
        result = generate_image(openai_client, prompt, title, local_path)
        if not result:
            return None
        
        # Rate limiting - be nice to OpenAI API
        time.sleep(1)
    
    # Upload to Firebase
    remote_path = f"story_covers/{local_filename}"
    public_url = upload_to_firebase(bucket, local_path, remote_path)
    
    return public_url


def update_stories_json(stories_data, story_index, image_url):
    """Update stories.json with the new image URL."""
    stories_data['stories'][story_index]['coverImageURL'] = image_url
    stories_data['stories'][story_index]['updatedAt'] = datetime.now().isoformat() + 'Z'


def save_stories_json(stories_data):
    """Save updated stories.json."""
    with open(STORIES_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(stories_data, f, ensure_ascii=False, indent=2)
    print(f"\n💾 Saved updated {STORIES_JSON_PATH}")


def main():
    parser = argparse.ArgumentParser(description='Generate story images and upload to Firebase')
    parser.add_argument('--test', action='store_true', help='Test with first story only')
    parser.add_argument('--level', type=int, help='Process stories for specific level (1-50)')
    parser.add_argument('--start', type=int, default=0, help='Start index for batch processing')
    parser.add_argument('--count', type=int, default=10, help='Number of stories to process')
    parser.add_argument('--all', action='store_true', help='Process ALL stories (500 images!)')
    
    args = parser.parse_args()
    
    # Check OpenAI API key
    if not os.getenv("OPENAI_API_KEY"):
        print("❌ Please set OPENAI_API_KEY environment variable")
        print("   export OPENAI_API_KEY='sk-...'")
        return
    
    # Initialize clients
    print("🔧 Initializing Firebase...")
    bucket = initialize_firebase()
    
    print("🔧 Initializing OpenAI...")
    openai_client = initialize_openai()
    
    # Load stories
    print(f"📚 Loading stories from {STORIES_JSON_PATH}...")
    with open(STORIES_JSON_PATH, 'r', encoding='utf-8') as f:
        stories_data = json.load(f)
    
    stories = stories_data['stories']
    print(f"   Total stories: {len(stories)}")
    
    # Create images directory
    os.makedirs(IMAGES_DIR, exist_ok=True)
    
    # Determine which stories to process
    if args.test:
        indices = [0]
        print(f"\n🧪 TEST MODE: Processing only first story\n")
    elif args.level:
        indices = [i for i, s in enumerate(stories) if s['difficultyLevel'] == args.level]
        print(f"\n🎯 Processing Level {args.level}: {len(indices)} stories\n")
    elif args.all:
        indices = list(range(len(stories)))
        print(f"\n🚀 PROCESSING ALL {len(stories)} STORIES!")
        print("   ⚠️  This will take a long time and cost money!")
        print("   💰 Estimated cost: ~${:.2f} (at $0.04 per image)\n".format(len(stories) * 0.04))
        confirm = input("   Type 'yes' to continue: ")
        if confirm != 'yes':
            print("   Cancelled.")
            return
    else:
        end = min(args.start + args.count, len(stories))
        indices = list(range(args.start, end))
        print(f"\n📦 Processing stories {args.start} to {end-1} ({len(indices)} stories)\n")
    
    # Process stories
    success_count = 0
    fail_count = 0
    
    for i, story_index in enumerate(indices):
        story = stories[story_index]
        
        print(f"\n[{i+1}/{len(indices)}] ", end="")
        
        image_url = process_story(openai_client, bucket, story, story_index, IMAGES_DIR)
        
        if image_url:
            update_stories_json(stories_data, story_index, image_url)
            success_count += 1
            
            # Save progress every 5 stories
            if success_count % 5 == 0:
                save_stories_json(stories_data)
        else:
            fail_count += 1
        
        # Rate limiting
        if i < len(indices) - 1:
            time.sleep(0.5)
    
    # Final save
    save_stories_json(stories_data)
    
    # Summary
    print("\n" + "="*60)
    print("📊 SUMMARY")
    print("="*60)
    print(f"✅ Successfully processed: {success_count}")
    print(f"❌ Failed: {fail_count}")
    print(f"💰 Estimated cost: ${success_count * 0.04:.2f}")
    print(f"📁 Images saved in: {IMAGES_DIR}/")
    print("="*60)


if __name__ == "__main__":
    main()
