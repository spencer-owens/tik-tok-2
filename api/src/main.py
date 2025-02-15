import os
import json
import time
import asyncio
import tempfile
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import replicate
import mux_python
import ffmpeg
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Peaceful Meditation API",
    description="API for AI-powered meditation music and peaceful video generation",
    version="1.0.0"
)

def log(message: str) -> None:
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

class GenerationResponse(BaseModel):
    """Response model for the combined generation endpoint."""
    success: bool
    mux_playback_id: Optional[str] = None
    mux_playback_url: Optional[str] = None
    status: str
    execution_time_seconds: float
    error: Optional[str] = None

async def generate_music() -> str:
    """Generate peaceful meditation music using Meta's MusicGen model."""
    log("🎵 Starting music generation")
    
    input_params = {
        "model_version": "large",
        "prompt": "peaceful ambient meditation music, calming lofi beats, gentle and soothing, no lyrics, soft piano and strings",
        "duration": 10,
        "temperature": 0.7,
        "top_k": 250,
        "top_p": 0.99,
        "classifier_free_guidance": 3,
        "output_format": "mp3"
    }
    log(f"Music generation parameters: {json.dumps(input_params, indent=2)}")
    
    output = replicate.run(
        "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
        input=input_params
    )
    
    if isinstance(output, list) and len(output) > 0:
        output_url = str(output[0])
    else:
        output_url = str(output)
    
    log(f"✅ Music generated: {output_url}")
    return output_url

async def generate_visualization() -> str:
    """Generate peaceful visualization using Luma Ray."""
    log("🎬 Starting visualization generation")
    
    input_params = {
        "prompt": "beautiful abstract peaceful animation, soft flowing colors, gentle transitions, meditative visuals",
        "negative_prompt": "text, watermark, ugly, distorted, noisy",
        "fps": 30,
        "num_frames": 90,
        "guidance_scale": 7.5,
        "num_inference_steps": 50,
        "width": 512,
        "height": 512,
        "scheduler": "DPM++ Karras SDE"
    }
    log(f"Visualization parameters: {json.dumps(input_params, indent=2)}")
    
    output = replicate.run(
        "luma/ray",
        input=input_params
    )
    
    output_url = str(output)
    log(f"✅ Visualization generated: {output_url}")
    return output_url

async def download_file(url: str, local_filename: str) -> str:
    """Download a file from a URL to a local file with progress logging."""
    log(f"📥 Downloading from {url}")
    
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

def merge_and_loop(video_path: str, audio_path: str, output_path: str, loops: int = 5) -> str:
    """Merge audio and video, then loop the result."""
    log("🔄 Starting merge and loop process")
    
    # First merge audio and video
    merged_path = os.path.join(os.path.dirname(output_path), "temp_merged.mp4")
    
    stream = ffmpeg.input(video_path)
    audio = ffmpeg.input(audio_path)
    stream = ffmpeg.output(stream, audio, merged_path,
                         acodec='aac',
                         vcodec='copy',
                         shortest=None)
    ffmpeg.run(stream, overwrite_output=True)
    
    # Create a temporary concat file
    concat_file = os.path.join(os.path.dirname(output_path), "concat.txt")
    with open(concat_file, "w") as f:
        for _ in range(loops):
            f.write(f"file '{os.path.abspath(merged_path)}'\n")
    
    # Use ffmpeg concat demuxer to loop the video
    stream = ffmpeg.input(concat_file, format='concat', safe=0)
    stream = ffmpeg.output(stream, output_path, c='copy')
    ffmpeg.run(stream, overwrite_output=True)
    
    # Clean up temporary files
    os.remove(concat_file)
    os.remove(merged_path)
    
    log(f"✅ Merge and loop complete: {output_path}")
    return output_path

def upload_to_mux(video_path: str) -> dict:
    """Upload video to Mux and create a playback ID."""
    log("📤 Starting Mux upload")
    
    # Configure Mux API client
    configuration = mux_python.Configuration()
    configuration.username = os.getenv("MUX_TOKEN_ID")
    configuration.password = os.getenv("MUX_TOKEN_SECRET")
    
    # Create upload
    uploads_api = mux_python.DirectUploadsApi(mux_python.ApiClient(configuration))
    create_upload_request = mux_python.CreateUploadRequest(
        new_asset_settings=mux_python.CreateAssetRequest(
            playback_policy=[mux_python.PlaybackPolicy.PUBLIC],
            test=False
        ),
        cors_origin="*"
    )
    
    upload = uploads_api.create_direct_upload(create_upload_request)
    
    # Upload file
    with open(video_path, 'rb') as f:
        response = requests.put(
            upload.data.url,
            data=f,
            headers={'Content-Type': 'video/mp4'}
        )
        response.raise_for_status()
    
    # Wait for upload to complete
    assets_api = mux_python.AssetsApi(mux_python.ApiClient(configuration))
    max_retries = 30
    asset_id = None
    
    while max_retries > 0:
        upload_status = uploads_api.get_direct_upload(upload.data.id)
        if upload_status.data.asset_id:
            asset_id = upload_status.data.asset_id
            break
        time.sleep(2)
        max_retries -= 1
    
    if not asset_id:
        raise Exception("Failed to get asset ID after upload")
    
    # Wait for asset to be ready
    asset = None
    max_retries = 30
    
    while max_retries > 0:
        asset = assets_api.get_asset(asset_id)
        if asset.data.status == "ready":
            break
        elif asset.data.status == "errored":
            raise Exception(f"Asset creation failed: {asset.data.errors}")
        time.sleep(5)
        max_retries -= 1
    
    if not asset or asset.data.status != "ready":
        raise Exception("Asset failed to become ready in time")
    
    playback_id = asset.data.playback_ids[0].id
    
    return {
        "asset_id": asset.data.id,
        "playback_id": playback_id,
        "playback_url": f"https://stream.mux.com/{playback_id}.m3u8"
    }

@app.post("/api/v1/generate-peaceful-content", response_model=GenerationResponse)
async def generate_peaceful_content():
    """Generate peaceful music and visuals, merge them, and upload to Mux."""
    start_time = time.time()
    log("🚀 Starting peaceful content generation process")
    
    try:
        # Create output directory if it doesn't exist
        os.makedirs("output", exist_ok=True)
        
        # Generate music and visualization in parallel
        music_url, viz_url = await asyncio.gather(
            generate_music(),
            generate_visualization()
        )
        
        # Create temporary directory for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download generated files
            audio_path = os.path.join(temp_dir, "audio.mp3")
            video_path = os.path.join(temp_dir, "video.mp4")
            
            await asyncio.gather(
                download_file(music_url, audio_path),
                download_file(viz_url, video_path)
            )
            
            # Merge and loop
            output_path = "output/merged_looped.mp4"
            merged_path = merge_and_loop(video_path, audio_path, output_path)
            
            # Upload to Mux
            mux_response = upload_to_mux(merged_path)
            
            total_time = time.time() - start_time
            log(f"✨ Process completed in {total_time:.2f} seconds")
            
            return GenerationResponse(
                success=True,
                mux_playback_id=mux_response["playback_id"],
                mux_playback_url=mux_response["playback_url"],
                status="completed",
                execution_time_seconds=round(total_time, 2)
            )
            
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"❌ Process failed: {error_msg}")
        
        return GenerationResponse(
            success=False,
            status="failed",
            error=error_msg,
            execution_time_seconds=round(time.time() - start_time, 2)
        )

@app.get("/")
async def read_root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "Peaceful Meditation API",
        "endpoints": [
            "/api/v1/generate-peaceful-content"
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
