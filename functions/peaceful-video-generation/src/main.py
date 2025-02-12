import os
import json
import time
import ffmpeg
import replicate
import requests
import tempfile
from pathlib import Path
from dotenv import load_dotenv
from loguru import logger
import mux_python
from mux_python.rest import ApiException

# Load environment variables
load_dotenv()

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "DEBUG")
logger.remove()  # Remove default handler
logger.add(
    "peaceful_video.log",
    rotation="1 day",
    retention="7 days",
    level=LOG_LEVEL,
    format="<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
)

def log_env_check():
    """Check and log the status of required environment variables."""
    required_vars = ["MUX_TOKEN_ID", "MUX_TOKEN_SECRET", "REPLICATE_API_KEY"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
    
    logger.info("✅ All required environment variables are present")

def download_file(url, local_filename):
    """Download a file from a URL to a local file with progress logging."""
    logger.info(f"📥 Starting download from {url}")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        with open(local_filename, 'wb') as f:
            if total_size == 0:
                logger.warning("⚠️ Content length header missing, cannot track progress")
            
            downloaded = 0
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total_size:
                    progress = (downloaded / total_size) * 100
                    logger.debug(f"Download progress: {progress:.1f}%")
        
        logger.success(f"✅ Successfully downloaded to {local_filename}")
        return local_filename
    except Exception as e:
        logger.error(f"❌ Download failed: {str(e)}")
        raise

def generate_music():
    """Generate peaceful music using Replicate's minimax/music-01 model."""
    logger.info("🎵 Starting music generation")
    try:
        client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))
        logger.debug("Replicate client initialized")
        
        logger.info("Sending request to music generation model")
        output = client.run(
            "minimax/music-01",
            input={
                "prompt": "peaceful ambient meditation music, calming lofi beats, gentle and soothing",
                "duration": 10
            }
        )
        
        logger.success(f"✅ Music generated successfully: {output}")
        return output
    except Exception as e:
        logger.error(f"❌ Music generation failed: {str(e)}")
        raise

def generate_video():
    """Generate peaceful video using Replicate's stable_diffusion_infinite_zoom model."""
    logger.info("🎬 Starting video generation")
    try:
        client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))
        logger.debug("Replicate client initialized")
        
        logger.info("Sending request to video generation model")
        output = client.run(
            "arielreplicate/stable_diffusion_infinite_zoom",
            input={
                "prompt": "abstract peaceful patterns, soft flowing colors, gentle transitions, meditative visuals",
                "duration": 10
            }
        )
        
        logger.success(f"✅ Video generated successfully: {output}")
        return output
    except Exception as e:
        logger.error(f"❌ Video generation failed: {str(e)}")
        raise

def merge_audio_video(video_path, audio_path, output_path):
    """Merge audio and video using ffmpeg with detailed logging."""
    logger.info("🔄 Starting audio/video merge")
    try:
        logger.debug(f"Input video: {video_path}")
        logger.debug(f"Input audio: {audio_path}")
        logger.debug(f"Output path: {output_path}")
        
        # Get input file information
        video_probe = ffmpeg.probe(video_path)
        audio_probe = ffmpeg.probe(audio_path)
        logger.debug(f"Video duration: {video_probe['format']['duration']}s")
        logger.debug(f"Audio duration: {audio_probe['format']['duration']}s")
        
        # Merge audio and video
        stream = ffmpeg.input(video_path)
        audio = ffmpeg.input(audio_path)
        stream = ffmpeg.output(stream, audio, output_path,
                             acodec='aac',
                             vcodec='copy',
                             shortest=None,
                             loglevel='debug')  # Enable detailed FFmpeg logging
        
        logger.info("Executing FFmpeg merge command")
        ffmpeg.run(stream, overwrite_output=True)
        
        # Verify output
        output_probe = ffmpeg.probe(output_path)
        logger.debug(f"Output file duration: {output_probe['format']['duration']}s")
        logger.debug(f"Output file size: {Path(output_path).stat().st_size} bytes")
        
        logger.success("✅ Audio/video merge completed successfully")
        return output_path
    except ffmpeg.Error as e:
        logger.error(f"❌ FFmpeg error during merge: {e.stderr.decode() if e.stderr else str(e)}")
        raise
    except Exception as e:
        logger.error(f"❌ Unexpected error during merge: {str(e)}")
        raise

def upload_to_mux(video_path):
    """Upload video to Mux and create a playback ID with detailed logging."""
    logger.info("📤 Starting Mux upload")
    try:
        # Configure Mux API client
        configuration = mux_python.Configuration()
        configuration.username = os.getenv("MUX_TOKEN_ID")
        configuration.password = os.getenv("MUX_TOKEN_SECRET")
        logger.debug("Mux client configured")
        
        # Create API client
        assets_api = mux_python.AssetsApi(mux_python.ApiClient(configuration))
        logger.debug("Mux Assets API client created")
        
        # Prepare upload request
        input_settings = [mux_python.InputSettings(url=video_path)]
        create_asset_request = mux_python.CreateAssetRequest(
            input=input_settings,
            playback_policy=[mux_python.PlaybackPolicy.PUBLIC]
        )
        logger.debug(f"Preparing to upload file: {video_path}")
        
        # Create the asset
        logger.info("Creating Mux asset")
        asset = assets_api.create_asset(create_asset_request)
        logger.success(f"✅ Asset created successfully: {asset.data.id}")
        
        # Get the playback ID
        playback_id = asset.data.playback_ids[0].id
        logger.info(f"Playback ID obtained: {playback_id}")
        
        response_data = {
            "asset_id": asset.data.id,
            "playback_id": playback_id,
            "playback_url": f"https://stream.mux.com/{playback_id}.m3u8"
        }
        logger.debug(f"Full Mux response data: {json.dumps(response_data, indent=2)}")
        
        return response_data
    except ApiException as e:
        logger.error(f"❌ Mux API error: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"❌ Unexpected error during Mux upload: {str(e)}")
        raise

def main(context):
    """Main function to handle the request with comprehensive logging."""
    logger.info("🚀 Starting peaceful video generation process")
    start_time = time.time()
    
    try:
        # Check environment variables
        log_env_check()
        
        # Generate content
        logger.info("Step 1: Generating audio content")
        audio_url = generate_music()
        logger.info("Step 2: Generating video content")
        video_url = generate_video()
        
        # Process files
        with tempfile.TemporaryDirectory() as temp_dir:
            logger.info(f"Created temporary directory: {temp_dir}")
            
            # Define paths
            audio_path = os.path.join(temp_dir, "audio.mp3")
            video_path = os.path.join(temp_dir, "video.mp4")
            merged_path = os.path.join(temp_dir, "merged.mp4")
            
            # Download files
            logger.info("Step 3: Downloading generated files")
            download_file(audio_url, audio_path)
            download_file(video_url, video_path)
            
            # Merge files
            logger.info("Step 4: Merging audio and video")
            merged_file = merge_audio_video(video_path, audio_path, merged_path)
            
            # Upload to Mux
            logger.info("Step 5: Uploading to Mux")
            mux_response = upload_to_mux(merged_file)
        
        # Calculate total processing time
        total_time = time.time() - start_time
        logger.success(f"✨ Process completed successfully in {total_time:.2f} seconds")
        
        return {
            "success": True,
            "mux_data": mux_response,
            "message": "Successfully generated and uploaded peaceful content",
            "processing_time": f"{total_time:.2f} seconds"
        }
            
    except Exception as e:
        logger.error(f"❌ Process failed: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "processing_time": f"{time.time() - start_time:.2f} seconds"
        } 