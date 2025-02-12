import os
import json
import time
import pytest
from dotenv import load_dotenv
import replicate
from fastapi.testclient import TestClient
from main import app

# Load environment variables
load_dotenv()

def log_response(data, title):
    """Pretty print API responses"""
    print(f"\n{'=' * 20} {title} {'=' * 20}")
    if isinstance(data, (dict, list)):
        print(json.dumps(data, indent=2))
    else:
        print(str(data))
    print("=" * (42 + len(title)))

def test_music_generation():
    """Test music generation functionality"""
    total_start_time = time.time()
    print("\n🎵 Testing Music Generation")
    
    # 1. Test direct Replicate API call
    print("\n1. Direct Replicate API Test")
    
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
    
    print("\nInput parameters:")
    log_response(input_params, "Input Parameters")
    
    print("\n⏳ Generating music...")
    print(f"🕒 Starting API call at: {time.strftime('%H:%M:%S')}")
    start_time = time.time()
    
    try:
        print("📡 Sending request to Replicate...")
        request_start = time.time()
        output = replicate.run(
            "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
            input=input_params
        )
        request_time = time.time() - request_start
        print(f"⏱️ Request completed in {request_time:.2f} seconds")
        
        generation_time = time.time() - start_time
        print(f"\n✅ Music generated in {generation_time:.2f} seconds")
        print(f"🕒 Finished at: {time.strftime('%H:%M:%S')}")
        
        # Handle FileOutput object
        if output:
            output_info = {
                "type": str(type(output)),
                "output_url": str(output[0]) if isinstance(output, list) and len(output) > 0 else str(output),
                "generation_time": f"{generation_time:.2f} seconds",
                "request_time": f"{request_time:.2f} seconds"
            }
            log_response(output_info, "Replicate API Response")
        else:
            print("\n❌ No output received from Replicate API")
            
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        print(f"Error type: {type(e).__name__}")
        import traceback
        print(traceback.format_exc())
        return
    
    # 2. Test FastAPI endpoint
    print("\n2. Testing FastAPI Endpoint")
    client = TestClient(app)
    
    try:
        api_start = time.time()
        print(f"🕒 Starting FastAPI test at: {time.strftime('%H:%M:%S')}")
        response = client.post("/generate-music", json=input_params)
        api_time = time.time() - api_start
        print(f"⏱️ FastAPI request completed in {api_time:.2f} seconds")
        
        log_response(response.json(), "FastAPI Endpoint Response")
        
        assert response.status_code == 200
        assert "output" in response.json()
        print("\n✅ FastAPI endpoint test passed")
        
    except Exception as e:
        print(f"\n❌ FastAPI Test Error: {str(e)}")
        print(f"Error type: {type(e).__name__}")
        import traceback
        print(traceback.format_exc())
    
    total_time = time.time() - total_start_time
    print(f"\n📊 Test Summary:")
    print(f"Total test duration: {total_time:.2f} seconds")
    print(f"Music generation time: {generation_time:.2f} seconds")
    print(f"FastAPI endpoint time: {api_time:.2f} seconds")

if __name__ == "__main__":
    test_music_generation()
