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

class VizGenerationResponse(BaseModel):
    """Response model for visualization generation endpoint."""
    success: bool
    job_id: Optional[str] = None
    output_url: Optional[str] = None
    status: str
    execution_time_seconds: float
    error: Optional[str] = None

@router.post("/generate-visualization", response_model=VizGenerationResponse)
async def generate_visualization():
    """Generate peaceful visualization using Luma Ray."""
    start_time = time.time()
    log("🎬 Starting visualization generation test")
    
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
            "prompt": "beautiful abstract peaceful animation, soft flowing colors, gentle transitions, meditative visuals",
            "negative_prompt": "text, watermark, ugly, distorted, noisy",
            "fps": 30,
            "num_frames": 90,  # 3 seconds at 30fps
            "guidance_scale": 7.5,
            "num_inference_steps": 50,
            "width": 512,
            "height": 512,
            "scheduler": "DPM++ Karras SDE"
        }
        log(f"Input parameters: {json.dumps(input_params, indent=2)}")
        
        # Generate visualization
        log("🎬 Starting visualization generation with Replicate")
        output = replicate.run(
            "luma/ray",
            input=input_params
        )
        
        # Process output
        output_url = str(output)  # Luma Ray returns a single URL string
        log(f"✅ Visualization generated successfully: {output_url}")
        
        # Calculate execution time
        execution_time = time.time() - start_time
        
        return VizGenerationResponse(
            success=True,
            output_url=output_url,
            status="completed",
            execution_time_seconds=round(execution_time, 2)
        )
        
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"❌ Process failed: {error_msg}")
        
        return VizGenerationResponse(
            success=False,
            status="failed",
            error=error_msg,
            execution_time_seconds=round(time.time() - start_time, 2)
        ) 