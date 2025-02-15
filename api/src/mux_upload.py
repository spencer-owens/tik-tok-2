import os
import json
import time
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel
import mux_python
from mux_python.rest import ApiException

# Create router
router = APIRouter()

def log(message: str) -> None:
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

class MuxUploadResponse(BaseModel):
    """Response model for Mux upload endpoint."""
    success: bool
    asset_id: Optional[str] = None
    playback_id: Optional[str] = None
    playback_url: Optional[str] = None
    status: str
    execution_time_seconds: float
    error: Optional[str] = None

def upload_to_mux(video_path: str) -> dict:
    """Upload video to Mux using direct upload and create a playback ID with detailed logging."""
    log("📤 Starting Mux upload")
    try:
        # Configure Mux API client
        configuration = mux_python.Configuration()
        configuration.username = os.getenv("MUX_TOKEN_ID")
        configuration.password = os.getenv("MUX_TOKEN_SECRET")
        log("Mux client configured")
        
        # Create API clients
        uploads_api = mux_python.DirectUploadsApi(mux_python.ApiClient(configuration))
        log("Mux Direct Uploads API client created")
        
        # Create a direct upload URL
        create_upload_request = mux_python.CreateUploadRequest(
            new_asset_settings=mux_python.CreateAssetRequest(
                playback_policy=[mux_python.PlaybackPolicy.PUBLIC],
                test=False,
                encoding_tier="baseline"
            ),
            cors_origin="*",
            timeout=3600
        )
        
        log("Creating direct upload")
        upload = uploads_api.create_direct_upload(create_upload_request)
        log(f"✅ Upload created with ID: {upload.data.id}")
        
        # Upload the file
        file_size = os.path.getsize(video_path)
        chunk_size = 5 * 1024 * 1024  # 5MB chunks
        
        with open(video_path, 'rb') as f:
            log(f"Uploading file to {upload.data.url}")
            log(f"File size: {file_size} bytes")
            
            import requests
            
            # For small files, upload in one request
            if file_size <= chunk_size:
                response = requests.put(
                    upload.data.url,
                    data=f,
                    headers={
                        'Content-Type': 'video/mp4',
                        'Content-Length': str(file_size)
                    }
                )
                response.raise_for_status()
            else:
                # For larger files, use chunked upload
                offset = 0
                while offset < file_size:
                    chunk = f.read(chunk_size)
                    if not chunk:
                        break
                        
                    end = min(offset + len(chunk), file_size)
                    content_range = f'bytes {offset}-{end-1}/{file_size}'
                    
                    log(f"Uploading chunk: {content_range}")
                    response = requests.put(
                        upload.data.url,
                        data=chunk,
                        headers={
                            'Content-Type': 'video/mp4',
                            'Content-Length': str(len(chunk)),
                            'Content-Range': content_range
                        }
                    )
                    
                    if response.status_code not in [200, 201, 308]:
                        raise Exception(f"Upload failed with status {response.status_code}: {response.text}")
                    
                    offset += len(chunk)
                    progress = (offset / file_size) * 100
                    log(f"Upload progress: {progress:.1f}%")
        
        log("✅ File uploaded successfully")
        
        # Wait for the upload to complete and get the asset ID
        max_retries = 30
        retry_count = 0
        asset_id = None
        
        while retry_count < max_retries and not asset_id:
            try:
                log(f"Checking upload status (attempt {retry_count + 1}/{max_retries})")
                upload_status = uploads_api.get_direct_upload(upload.data.id)
                if upload_status.data.asset_id:
                    asset_id = upload_status.data.asset_id
                    log(f"✅ Upload complete, got asset ID: {asset_id}")
                    break
                else:
                    log(f"Upload status: {upload_status.data.status}")
                    time.sleep(2)
                    retry_count += 1
            except Exception as e:
                log(f"Error checking upload status: {str(e)}")
                time.sleep(2)
                retry_count += 1
        
        if not asset_id:
            raise Exception("Failed to get asset ID after upload")
        
        # Wait for the asset to be ready
        assets_api = mux_python.AssetsApi(mux_python.ApiClient(configuration))
        max_retries = 30
        retry_count = 0
        asset = None
        
        while retry_count < max_retries:
            try:
                log(f"Checking asset status (attempt {retry_count + 1}/{max_retries})")
                asset = assets_api.get_asset(asset_id)
                
                if asset.data.status == "ready":
                    log("✅ Asset is ready")
                    break
                elif asset.data.status == "errored":
                    raise Exception(f"Asset creation failed: {asset.data.errors}")
                else:
                    log(f"Asset status: {asset.data.status}")
                    time.sleep(5)
                    retry_count += 1
            except Exception as e:
                log(f"Error checking asset status: {str(e)}")
                time.sleep(5)
                retry_count += 1
        
        if not asset or asset.data.status != "ready":
            raise Exception("Asset failed to become ready in time")
        
        # Get the playback ID
        playback_id = asset.data.playback_ids[0].id
        log(f"Playback ID obtained: {playback_id}")
        
        response_data = {
            "asset_id": asset.data.id,
            "playback_id": playback_id,
            "playback_url": f"https://stream.mux.com/{playback_id}.m3u8",
            "status": asset.data.status
        }
        log(f"Full Mux response data: {json.dumps(response_data, indent=2)}")
        
        return response_data
    except ApiException as e:
        log(f"❌ Mux API error: {str(e)}")
        raise
    except Exception as e:
        log(f"❌ Unexpected error during Mux upload: {str(e)}")
        raise

@router.post("/upload-to-mux", response_model=MuxUploadResponse)
async def upload_video(file: UploadFile = File(...)):
    """Upload a video file to Mux."""
    start_time = time.time()
    log("🚀 Starting Mux upload")
    
    try:
        # Check environment variables
        required_vars = ["MUX_TOKEN_ID", "MUX_TOKEN_SECRET"]
        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            raise HTTPException(
                status_code=500,
                detail=f"Missing required environment variables: {', '.join(missing_vars)}"
            )
        log("✅ All required environment variables are present")
        
        # Save uploaded file temporarily
        import tempfile
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_file:
            temp_file.write(await file.read())
            temp_path = temp_file.name
            log(f"Saved uploaded file to: {temp_path}")
        
        try:
            # Upload to Mux
            mux_response = upload_to_mux(temp_path)
            
            # Calculate total processing time
            total_time = time.time() - start_time
            log(f"✨ Process completed successfully in {total_time:.2f} seconds")
            
            return MuxUploadResponse(
                success=True,
                asset_id=mux_response["asset_id"],
                playback_id=mux_response["playback_id"],
                playback_url=mux_response["playback_url"],
                status="completed",
                execution_time_seconds=round(total_time, 2)
            )
            
        finally:
            # Clean up temporary file
            os.unlink(temp_path)
            log("🧹 Cleaned up temporary file")
            
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"❌ Process failed: {error_msg}")
        
        return MuxUploadResponse(
            success=False,
            status="failed",
            error=error_msg,
            execution_time_seconds=round(time.time() - start_time, 2)
        ) 