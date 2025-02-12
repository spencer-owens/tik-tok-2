import os
import json
import time
import ffmpeg
import replicate
import requests
import tempfile
from pathlib import Path
from dotenv import load_dotenv
import mux_python
from mux_python.rest import ApiException

# Load environment variables
load_dotenv()

def check_env_vars(context):
    """Check and log the status of required environment variables."""
    required_vars = ["MUX_TOKEN_ID", "MUX_TOKEN_SECRET", "REPLICATE_API_KEY"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        context.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
    
    context.log("✅ All required environment variables are present")

def download_file(url, local_filename, context):
    """Download a file from a URL to a local file with progress logging."""
    context.log(f"📥 Starting download from {url}")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        with open(local_filename, 'wb') as f:
            if total_size == 0:
                context.log("⚠️ Content length header missing, cannot track progress")
            
            downloaded = 0
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total_size:
                    progress = (downloaded / total_size) * 100
                    context.log(f"Download progress: {progress:.1f}%")
        
        context.log(f"✅ Successfully downloaded to {local_filename}")
        return local_filename
    except Exception as e:
        context.error(f"❌ Download failed: {str(e)}")
        raise

def generate_music(context):
    """Generate peaceful music using Replicate's minimax/music-01 model."""
    context.log("🎵 Starting music generation")
    try:
        client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))
        context.log("Replicate client initialized")
        
        context.log("Sending request to music generation model")
        output = client.run(
            "minimax/music-01",
            input={
                "prompt": "peaceful ambient meditation music, calming lofi beats, gentle and soothing",
                "duration": 10
            }
        )
        
        context.log(f"✅ Music generated successfully: {output}")
        return output
    except Exception as e:
        context.error(f"❌ Music generation failed: {str(e)}")
        raise

def generate_video(context):
    """Generate peaceful video using Replicate's stable_diffusion_infinite_zoom model."""
    context.log("🎬 Starting video generation")
    try:
        client = replicate.Client(api_token=os.getenv("REPLICATE_API_KEY"))
        context.log("Replicate client initialized")
        
        context.log("Sending request to video generation model")
        output = client.run(
            "arielreplicate/stable_diffusion_infinite_zoom",
            input={
                "prompt": "abstract peaceful patterns, soft flowing colors, gentle transitions, meditative visuals",
                "duration": 10
            }
        )
        
        context.log(f"✅ Video generated successfully: {output}")
        return output
    except Exception as e:
        context.error(f"❌ Video generation failed: {str(e)}")
        raise

def merge_audio_video(video_path, audio_path, output_path, context):
    """Merge audio and video using ffmpeg with detailed logging."""
    context.log("🔄 Starting audio/video merge")
    try:
        context.log(f"Input video: {video_path}")
        context.log(f"Input audio: {audio_path}")
        context.log(f"Output path: {output_path}")
        
        # Get input file information
        video_probe = ffmpeg.probe(video_path)
        audio_probe = ffmpeg.probe(audio_path)
        context.log(f"Video duration: {video_probe['format']['duration']}s")
        context.log(f"Audio duration: {audio_probe['format']['duration']}s")
        
        # Merge audio and video
        stream = ffmpeg.input(video_path)
        audio = ffmpeg.input(audio_path)
        stream = ffmpeg.output(stream, audio, output_path,
                             acodec='aac',
                             vcodec='copy',
                             shortest=None,
                             loglevel='debug')
        
        context.log("Executing FFmpeg merge command")
        ffmpeg.run(stream, overwrite_output=True)
        
        # Verify output
        output_probe = ffmpeg.probe(output_path)
        context.log(f"Output file duration: {output_probe['format']['duration']}s")
        context.log(f"Output file size: {Path(output_path).stat().st_size} bytes")
        
        context.log("✅ Audio/video merge completed successfully")
        return output_path
    except ffmpeg.Error as e:
        context.error(f"❌ FFmpeg error during merge: {e.stderr.decode() if e.stderr else str(e)}")
        raise
    except Exception as e:
        context.error(f"❌ Unexpected error during merge: {str(e)}")
        raise

def upload_to_mux(video_path, context):
    """Upload video to Mux and create a playback ID with detailed logging."""
    context.log("📤 Starting Mux upload")
    try:
        # Configure Mux API client
        configuration = mux_python.Configuration()
        configuration.username = os.getenv("MUX_TOKEN_ID")
        configuration.password = os.getenv("MUX_TOKEN_SECRET")
        context.log("Mux client configured")
        
        # Create API client
        assets_api = mux_python.AssetsApi(mux_python.ApiClient(configuration))
        context.log("Mux Assets API client created")
        
        # Prepare upload request
        input_settings = [mux_python.InputSettings(url=video_path)]
        create_asset_request = mux_python.CreateAssetRequest(
            input=input_settings,
            playback_policy=[mux_python.PlaybackPolicy.PUBLIC]
        )
        context.log(f"Preparing to upload file: {video_path}")
        
        # Create the asset
        context.log("Creating Mux asset")
        asset = assets_api.create_asset(create_asset_request)
        context.log(f"✅ Asset created successfully: {asset.data.id}")
        
        # Get the playback ID
        playback_id = asset.data.playback_ids[0].id
        context.log(f"Playback ID obtained: {playback_id}")
        
        response_data = {
            "asset_id": asset.data.id,
            "playback_id": playback_id,
            "playback_url": f"https://stream.mux.com/{playback_id}.m3u8"
        }
        context.log(f"Full Mux response data: {json.dumps(response_data, indent=2)}")
        
        return response_data
    except ApiException as e:
        context.error(f"❌ Mux API error: {str(e)}")
        raise
    except Exception as e:
        context.error(f"❌ Unexpected error during Mux upload: {str(e)}")
        raise

def main(context):
    """Main function to handle the request with comprehensive logging."""
    # Immediate entry point verification
    context.log("🎯 Function entry point reached")
    context.log(f"Request method: {context.req.method}")
    context.log(f"Request headers: {json.dumps(dict(context.req.headers), indent=2)}")
    context.log(f"Request body: {context.req.bodyText if hasattr(context.req, 'bodyText') else 'No body'}")
    
    context.log("🚀 Starting peaceful video generation process")
    start_time = time.time()
    
    try:
        # Check environment variables
        check_env_vars(context)
        
        # Generate content
        context.log("Step 1: Generating audio content")
        audio_url = generate_music(context)
        context.log("Step 2: Generating video content")
        video_url = generate_video(context)
        
        # Process files
        with tempfile.TemporaryDirectory() as temp_dir:
            context.log(f"Created temporary directory: {temp_dir}")
            
            # Define paths
            audio_path = os.path.join(temp_dir, "audio.mp3")
            video_path = os.path.join(temp_dir, "video.mp4")
            merged_path = os.path.join(temp_dir, "merged.mp4")
            
            # Download files
            context.log("Step 3: Downloading generated files")
            download_file(audio_url, audio_path, context)
            download_file(video_url, video_path, context)
            
            # Merge files
            context.log("Step 4: Merging audio and video")
            merged_file = merge_audio_video(video_path, audio_path, merged_path, context)
            
            # Upload to Mux
            context.log("Step 5: Uploading to Mux")
            mux_response = upload_to_mux(merged_file, context)
        
        # Calculate total processing time
        total_time = time.time() - start_time
        context.log(f"✨ Process completed successfully in {total_time:.2f} seconds")
        
        return context.res.json({
            "success": True,
            "mux_data": mux_response,
            "message": "Successfully generated and uploaded peaceful content",
            "processing_time": f"{total_time:.2f} seconds"
        })
            
    except Exception as e:
        context.error(f"❌ Process failed: {str(e)}")
        return context.res.json({
            "success": False,
            "error": str(e),
            "processing_time": f"{time.time() - start_time:.2f} seconds"
        }) 