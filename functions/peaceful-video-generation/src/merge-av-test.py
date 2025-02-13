import os
import json
import time
import asyncio
import tempfile
from datetime import datetime
from dotenv import load_dotenv
from appwrite.client import Client
from appwrite.services.databases import Databases
import ffmpeg
import requests
from appwrite.query import Query

# Load environment variables
load_dotenv()

# Initialize Appwrite
client = Client()
client.set_endpoint('https://cloud.appwrite.io/v1')
client.set_project(os.getenv('APPWRITE_PROJECT_ID'))
client.set_key(os.getenv('APPWRITE_API_KEY'))
databases = Databases(client)

# Constants
DATABASE_ID = "67a580230029e01e56af"
MUSIC_COLLECTION_ID = "67acd38e002a566db74a"  # music_generation_jobs
VIDEO_COLLECTION_ID = "67acf64500037ab9c429"  # viz-generation-jobs

def log(message):
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def download_file(url, local_filename):
    """Download a file from a URL to a local file with progress logging."""
    log(f"📥 Downloading from {url}")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        with open(local_filename, 'wb') as f:
            if total_size == 0:
                log("⚠️ Content length header missing, cannot track progress")
            
            downloaded = 0
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total_size:
                    progress = (downloaded / total_size) * 100
                    log(f"Download progress: {progress:.1f}%")
        
        log(f"✅ Successfully downloaded to {local_filename}")
        return local_filename
    except Exception as e:
        log(f"❌ Download failed: {str(e)}")
        raise

def get_latest_successful_job(collection_id):
    """Get the most recent successfully completed job from a collection."""
    try:
        # First get all completed jobs
        response = databases.list_documents(
            database_id=DATABASE_ID,
            collection_id=collection_id,
            queries=[
                Query.equal('status', 'completed'),
                Query.order_desc('$createdAt'),
                Query.limit(1)
            ]
        )
        
        if response['total'] > 0:
            return response['documents'][0]
        return None
    except Exception as e:
        log(f"❌ Failed to get latest job: {str(e)}")
        raise

def merge_audio_video(video_path, audio_path, output_path):
    """Merge audio and video using ffmpeg with detailed logging."""
    try:
        log(f"🎬 Input video: {video_path}")
        log(f"🎵 Input audio: {audio_path}")
        log(f"📦 Output path: {output_path}")
        
        # Get input file information
        video_probe = ffmpeg.probe(video_path)
        audio_probe = ffmpeg.probe(audio_path)
        log(f"Video duration: {video_probe['format']['duration']}s")
        log(f"Audio duration: {audio_probe['format']['duration']}s")
        
        # Merge audio and video
        stream = ffmpeg.input(video_path)
        audio = ffmpeg.input(audio_path)
        stream = ffmpeg.output(stream, audio, output_path,
                             acodec='aac',
                             vcodec='copy',
                             shortest=None,
                             loglevel='debug')
        
        log("🔄 Executing FFmpeg merge command")
        ffmpeg.run(stream, overwrite_output=True)
        
        # Verify output
        output_probe = ffmpeg.probe(output_path)
        log(f"Output file duration: {output_probe['format']['duration']}s")
        log(f"Output file size: {os.path.getsize(output_path)} bytes")
        
        log("✅ Audio/video merge completed successfully")
        return output_path
    except ffmpeg.Error as e:
        log(f"❌ FFmpeg error: {e.stderr.decode() if e.stderr else str(e)}")
        raise
    except Exception as e:
        log(f"❌ Unexpected error: {str(e)}")
        raise

async def main():
    """Main function to run the test."""
    log("🚀 Starting audio/video merge test")
    
    try:
        # Get latest successful jobs
        log("🔍 Finding latest successful music generation")
        music_job = get_latest_successful_job(MUSIC_COLLECTION_ID)
        if not music_job:
            raise Exception("No successful music generation found")
        log(f"Found music: {music_job['output_url']}")
        
        log("🔍 Finding latest successful video generation")
        video_job = get_latest_successful_job(VIDEO_COLLECTION_ID)
        if not video_job:
            raise Exception("No successful video generation found")
        log(f"Found video: {video_job['output_url']}")
        
        # Create temporary directory for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            log(f"📁 Created temporary directory: {temp_dir}")
            
            # Download files
            audio_path = os.path.join(temp_dir, "audio.mp3")
            video_path = os.path.join(temp_dir, "video.mp4")
            output_path = os.path.join(temp_dir, "merged.mp4")
            
            log("⬇️ Downloading audio file")
            download_file(music_job['output_url'], audio_path)
            
            log("⬇️ Downloading video file")
            download_file(video_job['output_url'], video_path)
            
            # Merge files
            log("🔄 Merging audio and video")
            merged_path = merge_audio_video(video_path, audio_path, output_path)
            
            # Copy to a permanent location
            final_output = "output/merged.mp4"
            os.makedirs("output", exist_ok=True)
            import shutil
            shutil.copy2(merged_path, final_output)
            log(f"✨ Final output saved to: {os.path.abspath(final_output)}")
            
    except Exception as e:
        log(f"💥 Test failed: {str(e)}")
        raise

if __name__ == "__main__":
    asyncio.run(main()) 