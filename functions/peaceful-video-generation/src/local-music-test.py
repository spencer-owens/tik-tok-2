import os
import json
import time
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from appwrite.client import Client
from appwrite.services.databases import Databases
import replicate
import requests

# Load environment variables
load_dotenv()

# Initialize Appwrite
client = Client()
client.set_endpoint('https://cloud.appwrite.io/v1')
client.set_project(os.getenv('APPWRITE_PROJECT_ID'))
client.set_key(os.getenv('APPWRITE_API_KEY'))
databases = Databases(client)

# Constants
DATABASE_ID = "67a580230029e01e56af"
COLLECTION_ID = "67acd38e002a566db74a"

def log(message):
    """Simple logging with timestamp."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def check_url_accessibility(url):
    """Check if a URL is accessible and return response details."""
    try:
        response = requests.head(url, allow_redirects=True)
        return {
            "status_code": response.status_code,
            "accessible": response.status_code == 200,
            "headers": dict(response.headers),
            "url": response.url
        }
    except Exception as e:
        return {
            "status_code": None,
            "accessible": False,
            "error": str(e),
            "url": url
        }

async def generate_music():
    """Generate music using Replicate with detailed logging."""
    try:
        log("🔑 Checking Replicate API token...")
        if not os.getenv('REPLICATE_API_TOKEN'):
            raise ValueError("Missing REPLICATE_API_TOKEN")
        log("✅ Replicate API token found")
        
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
        log(f"📝 Input parameters prepared: {json.dumps(input_params, indent=2)}")
        
        # Create job document
        job = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id='unique()',
            data={
                'status': 'processing',
                'prompt': input_params['prompt'],
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
        )
        job_id = job['$id']
        log(f"📄 Created job document with ID: {job_id}")
        
        # Generate music
        log("🎵 Starting music generation...")
        start_time = time.time()
        output = replicate.run(
            "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
            input=input_params
        )
        generation_time = time.time() - start_time
        log(f"⏱️ Generation took {generation_time:.2f} seconds")
        
        # Log output details
        log(f"📦 Raw output type: {type(output)}")
        log(f"📦 Raw output value: {output}")
        if isinstance(output, list):
            log(f"📦 Output is a list of length: {len(output)}")
            for i, item in enumerate(output):
                log(f"📦 Item {i} type: {type(item)}")
                log(f"📦 Item {i} value: {item}")
        
        # Determine output URL
        if isinstance(output, list) and len(output) > 0:
            output_url = str(output[0])
        else:
            output_url = str(output)
        log(f"🔗 Final output URL: {output_url}")
        
        # Check URL accessibility
        log("🔍 Checking URL accessibility...")
        url_check = check_url_accessibility(output_url)
        log(f"🔍 URL check results: {json.dumps(url_check, indent=2)}")
        
        # Update job document
        update_data = {
            'status': 'completed',
            'output_url': output_url,
            'execution_time_seconds': round(generation_time, 2),
            'updated_at': datetime.now().isoformat()
        }
        databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id=job_id,
            data=update_data
        )
        log(f"✅ Updated job document with results")
        
        return {
            "success": True,
            "job_id": job_id,
            "output_url": output_url,
            "generation_time": generation_time,
            "url_check": url_check
        }
        
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"❌ Error: {error_msg}")
        if 'job_id' in locals():
            try:
                databases.update_document(
                    database_id=DATABASE_ID,
                    collection_id=COLLECTION_ID,
                    document_id=job_id,
                    data={
                        'status': 'failed',
                        'error': error_msg,
                        'updated_at': datetime.now().isoformat()
                    }
                )
                log("📝 Updated job document with error status")
            except Exception as update_error:
                log(f"❌ Failed to update job with error: {str(update_error)}")
        raise

async def main():
    """Main function to run the test."""
    log("🚀 Starting local music generation test")
    try:
        result = await generate_music()
        log(f"✨ Test completed successfully: {json.dumps(result, indent=2)}")
    except Exception as e:
        log(f"💥 Test failed: {str(e)}")

if __name__ == "__main__":
    asyncio.run(main()) 