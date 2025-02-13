import os
import json
import time
from pathlib import Path
from dotenv import load_dotenv
import mux_python
from mux_python.rest import ApiException

# Load environment variables
load_dotenv()

def log(message):
    """Simple logging with timestamp."""
    from datetime import datetime
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def create_simulated_live_stream(asset_id, duration_seconds=60):
    """Create a simulated live stream using an existing asset."""
    log("🎬 Starting simulated live stream setup")
    try:
        # Configure Mux API client
        configuration = mux_python.Configuration()
        configuration.username = os.getenv("MUX_TOKEN_ID")
        configuration.password = os.getenv("MUX_TOKEN_SECRET")
        log("Mux client configured")
        
        # Create API clients
        live_api = mux_python.LiveStreamsApi(mux_python.ApiClient(configuration))
        log("Mux Live Streams API client created")
        
        # Create a new live stream
        create_stream_request = mux_python.CreateLiveStreamRequest(
            playback_policy=[mux_python.PlaybackPolicy.PUBLIC],
            new_asset_settings=mux_python.CreateAssetRequest(
                playback_policy=[mux_python.PlaybackPolicy.PUBLIC]
            ),
            test=False
        )
        
        log("Creating live stream")
        live_stream = live_api.create_live_stream(create_stream_request)
        log(f"✅ Live stream created with ID: {live_stream.data.id}")
        
        # Create a playback ID for the live stream
        playback_id = live_stream.data.playback_ids[0].id
        log(f"Live stream playback ID: {playback_id}")
        
        # Create simulated live stream using the asset
        log(f"Setting up simulation with asset ID: {asset_id}")
        
        # Create a simulcast target for the live stream
        simulcast_request = mux_python.CreateSimulcastTargetRequest(
            passthrough="simulated_live",
            stream_key=live_stream.data.stream_key,
            url=f"rtmp://global-live.mux.com/{live_stream.data.stream_key}"
        )
        
        # Start the simulation by creating a simulcast target
        log("Starting simulation")
        simulcast = live_api.create_live_stream_simulcast_target(
            live_stream.data.id,
            simulcast_request
        )
        
        response_data = {
            "live_stream_id": live_stream.data.id,
            "playback_id": playback_id,
            "playback_url": f"https://stream.mux.com/{playback_id}.m3u8",
            "status": live_stream.data.status,
            "stream_key": live_stream.data.stream_key,
            "simulcast_id": simulcast.data.id
        }
        
        log(f"Full live stream response data: {json.dumps(response_data, indent=2)}")
        return response_data
        
    except ApiException as e:
        log(f"❌ Mux API error: {str(e)}")
        raise
    except Exception as e:
        log(f"❌ Unexpected error during live stream setup: {str(e)}")
        raise

def main():
    """Main function to test simulated live stream setup."""
    log("🚀 Starting simulated live stream test")
    start_time = time.time()
    
    try:
        # Check environment variables
        required_vars = ["MUX_TOKEN_ID", "MUX_TOKEN_SECRET"]
        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
        log("✅ All required environment variables are present")
        
        # Use the asset ID from our previous upload
        asset_id = "JilZH8uTSaFNba39ggo4Il200s00wNKIkjM9njm7501EC00"  # Replace with your asset ID
        
        # Create simulated live stream
        live_response = create_simulated_live_stream(asset_id)
        
        # Calculate total processing time
        total_time = time.time() - start_time
        log(f"✨ Process completed successfully in {total_time:.2f} seconds")
        
        # Print final live stream URL
        log("\n🎬 Your live stream is ready!")
        log(f"Live Stream URL: {live_response['playback_url']}")
        log(f"Stream Key: {live_response['stream_key']}")
        log(f"Live Stream ID: {live_response['live_stream_id']}")
        
    except Exception as e:
        log(f"❌ Process failed: {str(e)}")
        raise

if __name__ == "__main__":
    main() 