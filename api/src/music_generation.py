import os
import json
import time
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import replicate

# Create router
router = APIRouter()

def log(message: str) -> None:
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

class MusicGenerationResponse(BaseModel):
    """Response model for music generation endpoint."""
    success: bool
    job_id: Optional[str] = None
    output_url: Optional[str] = None
    status: str
    execution_time_seconds: float
    error: Optional[str] = None

@router.post("/generate-music", response_model=MusicGenerationResponse)
async def generate_music():
    """Generate peaceful meditation music using Meta's MusicGen model."""
    start_time = time.time()
    log("🎵 Starting music generation test")
    
    try:
        # Check environment variables
        if not os.getenv('REPLICATE_API_TOKEN'):
            raise HTTPException(
                status_code=500,
                detail="Missing REPLICATE_API_TOKEN environment variable"
            )
        
        log("✅ Found Replicate API token")
        
        # Prepare input parameters
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
        log(f"Input parameters: {json.dumps(input_params, indent=2)}")
        
        # Generate music
        log("🎵 Starting music generation with Replicate")
        output = replicate.run(
            "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
            input=input_params
        )
        
        # Process output
        if isinstance(output, list) and len(output) > 0:
            output_url = str(output[0])
        else:
            output_url = str(output)
        
        log(f"✅ Music generated successfully: {output_url}")
        
        # Calculate execution time
        execution_time = time.time() - start_time
        
        return MusicGenerationResponse(
            success=True,
            output_url=output_url,
            status="completed",
            execution_time_seconds=round(execution_time, 2)
        )
        
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"❌ Process failed: {error_msg}")
        
        return MusicGenerationResponse(
            success=False,
            status="failed",
            error=error_msg,
            execution_time_seconds=round(time.time() - start_time, 2)
        ) 