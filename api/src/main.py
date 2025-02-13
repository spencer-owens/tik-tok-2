import os
import json
import time
from typing import Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
import replicate

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Peaceful Meditation API",
    description="API for AI-powered meditation music and peaceful video generation",
    version="1.0.0"
)

class MusicGenerationResponse(BaseModel):
    """Response model for music generation endpoint."""
    success: bool
    output: Optional[str] = None
    message: str
    execution_time_seconds: float
    error: Optional[str] = None
    error_type: Optional[str] = None

class MusicGenerationInput(BaseModel):
    model_version: str = "large"
    prompt: str
    duration: int = 10
    temperature: float = 0.7
    top_k: int = 250
    top_p: float = 0.99
    classifier_free_guidance: int = 3
    output_format: str = "mp3"

@app.get("/")
async def read_root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "Peaceful Meditation API"
    }

@app.post("/generate-music")
async def generate_music(input_params: MusicGenerationInput):
    """Generate meditation music using Replicate's MusicGen model."""
    try:
        output = replicate.run(
            "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
            input=input_params.model_dump()
        )
        
        if not output:
            raise HTTPException(status_code=500, detail="No output received from Replicate API")
        
        return {
            "success": True,
            "output": str(output[0]) if isinstance(output, list) and len(output) > 0 else str(output),
            "execution_time_seconds": None  # We'll add timing in a future update
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate music: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
