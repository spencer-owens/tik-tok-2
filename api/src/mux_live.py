import os
import json
import time
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import mux_python

# Create router
router = APIRouter()

def log(message: str) -> None:
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

class LiveStreamResponse(BaseModel):
    """Response model for live stream endpoint."""
    success: bool
    status: str
    execution_time_seconds: float
    error: Optional[str] = None

@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "message": "Live streaming service is healthy"} 