import os
import json
import time
import tempfile
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import ffmpeg
import requests

# Create router
router = APIRouter()

def log(message: str) -> None:
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

class MergeRequest(BaseModel):
    """Request model for merge endpoint."""
    audio_url: str
    video_url: str

class MergeResponse(BaseModel):
    """Response model for merge endpoint."""
    success: bool
    output_path: Optional[str] = None
    status: str
    execution_time_seconds: float
    error: Optional[str] = None

def download_file(url: str, local_filename: str) -> str:
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

def merge_audio_video(video_path: str, audio_path: str, output_path: str) -> str:
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

def loop_video(input_path: str, output_path: str, loops: int = 5) -> str:
    """Loop a video file multiple times using ffmpeg concat."""
    try:
        log(f"🔁 Looping video {loops} times")
        log(f"Input video: {input_path}")
        log(f"Output path: {output_path}")
        
        # Create a temporary concat file
        concat_file = os.path.join(os.path.dirname(input_path), "concat.txt")
        with open(concat_file, "w") as f:
            for _ in range(loops):
                f.write(f"file '{os.path.abspath(input_path)}'\n")
        
        log(f"Created concat file with {loops} entries")
        
        # Use ffmpeg concat demuxer to loop the video
        stream = ffmpeg.input(concat_file, format='concat', safe=0)
        stream = ffmpeg.output(stream, output_path,
                             c='copy',  # Copy both audio and video streams
                             loglevel='debug')
        
        log("🔄 Executing FFmpeg loop command")
        ffmpeg.run(stream, overwrite_output=True)
        
        # Clean up concat file
        os.remove(concat_file)
        log("🧹 Cleaned up temporary concat file")
        
        # Verify output
        output_probe = ffmpeg.probe(output_path)
        log(f"Final video duration: {output_probe['format']['duration']}s")
        log(f"Final video size: {os.path.getsize(output_path)} bytes")
        
        log("✅ Video looping completed successfully")
        return output_path
    except ffmpeg.Error as e:
        log(f"❌ FFmpeg error during looping: {e.stderr.decode() if e.stderr else str(e)}")
        raise
    except Exception as e:
        log(f"❌ Unexpected error during looping: {str(e)}")
        raise

@router.post("/merge-av", response_model=MergeResponse)
async def merge_av(request: MergeRequest):
    """Merge audio and video files from URLs and loop the result."""
    start_time = time.time()
    log("🎬 Starting audio/video merge and loop process")
    
    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            log(f"📁 Created temporary directory: {temp_dir}")
            
            # Define paths
            audio_path = os.path.join(temp_dir, "audio.mp3")
            video_path = os.path.join(temp_dir, "video.mp4")
            merged_path = os.path.join(temp_dir, "merged.mp4")
            final_output = "output/merged_looped.mp4"
            
            # Download files
            log("⬇️ Downloading audio file")
            download_file(request.audio_url, audio_path)
            
            log("⬇️ Downloading video file")
            download_file(request.video_url, video_path)
            
            # Merge files
            log("🔄 Merging audio and video")
            merged_path = merge_audio_video(video_path, audio_path, merged_path)
            
            # Create output directory if it doesn't exist
            os.makedirs("output", exist_ok=True)
            
            # Loop the merged video
            log("🔁 Creating looped version")
            looped_path = loop_video(merged_path, final_output)
            
            log(f"✨ Final output saved to: {os.path.abspath(final_output)}")
            
            # Calculate execution time
            execution_time = time.time() - start_time
            
            return MergeResponse(
                success=True,
                output_path=os.path.abspath(final_output),
                status="completed",
                execution_time_seconds=round(execution_time, 2)
            )
            
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"❌ Process failed: {error_msg}")
        
        return MergeResponse(
            success=False,
            status="failed",
            error=error_msg,
            execution_time_seconds=round(time.time() - start_time, 2)
        ) 