import os
import json
import time
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from appwrite.client import Client
from appwrite.services.databases import Databases
import replicate

# Load environment variables
load_dotenv()

# Initialize Appwrite (using function context)
client = None
databases = None

def init_appwrite(context):
    """Initialize Appwrite client with function context."""
    global client, databases
    client = Client()
    
    # Log available environment info
    context.log("Available environment variables:")
    context.log(str(dir(context)))
    
    # Initialize with function environment
    client.set_endpoint('https://cloud.appwrite.io/v1')
    client.set_project(os.getenv('APPWRITE_FUNCTION_PROJECT_ID', ''))
    client.set_key(os.getenv('APPWRITE_FUNCTION_API_KEY', ''))
    databases = Databases(client)

# Constants
DATABASE_ID = "67a580230029e01e56af"
COLLECTION_ID = "67acf64500037ab9c429"  # viz-generation-jobs collection

def safe_json_dumps(obj):
    """Safely convert object to JSON string."""
    return json.dumps(obj, indent=2, default=str)

async def generate_visualization(context, input_params):
    """Async function to generate visualization using Luma Ray."""
    try:
        # Log the API token status
        context.log(f"Using Replicate API token: {'Present' if os.getenv('REPLICATE_API_TOKEN') else 'Missing'}")
        
        return replicate.run(
            "luma/ray",
            input=input_params
        )
    except Exception as e:
        context.error(f"Visualization generation error: {str(e)}")
        context.error(f"Error type: {type(e).__name__}")
        context.error(f"Full error details: {str(e)}")
        raise

def create_job_document(prompt):
    """Create a new job document in Appwrite."""
    try:
        return databases.create_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id='unique()',
            data={
                'status': 'processing',
                'prompt': prompt,
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
        )
    except Exception as e:
        raise Exception(f"Failed to create job document: {str(e)}")

def update_job_document(job_id, data):
    """Update an existing job document in Appwrite."""
    try:
        data['updated_at'] = datetime.now().isoformat()
        return databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id=job_id,
            data=data
        )
    except Exception as e:
        raise Exception(f"Failed to update job document: {str(e)}")

async def process_visualization_generation(context, job_id, input_params, start_time):
    """Process visualization generation in the background."""
    try:
        # Start visualization generation
        context.log("🎬 Starting visualization generation")
        output = await generate_visualization(context, input_params)
        
        # Calculate execution time
        execution_time = time.time() - start_time
        
        # Update job with success
        update_job_document(job_id, {
            'status': 'completed',
            'output_url': str(output) if isinstance(output, str) else str(output[0]),
            'execution_time_seconds': round(execution_time, 2)
        })
        
        context.log(f"✅ Job completed successfully in {execution_time:.2f} seconds")
        
    except Exception as e:
        # Update job with error
        error_msg = f"{type(e).__name__}: {str(e)}"
        update_job_document(job_id, {
            'status': 'failed',
            'error': error_msg,
            'execution_time_seconds': round(time.time() - start_time, 2)
        })
        context.error(f"❌ Job failed: {error_msg}")

async def main(context):
    """Main function handler for visualization generation."""
    start_time = time.time()
    context.log("🎯 Test function entry point reached")
    
    # Initialize Appwrite
    init_appwrite(context)
    context.log("✅ Initialized Appwrite client")
    
    # Log request details
    context.log(f"Request method: {context.req.method}")
    context.log(f"Request path: {context.req.path}")
    context.log(f"Request headers: {safe_json_dumps(dict(context.req.headers))}")
    
    # Handle non-API requests
    if context.req.path and context.req.path != "/":
        return context.res.json({
            "success": False,
            "error": "Invalid endpoint. Please use the root path '/' for visualization generation.",
            "path": context.req.path
        }, 404)
    
    # Check environment variables
    if not os.getenv('REPLICATE_API_TOKEN'):
        error_msg = "Missing REPLICATE_API_TOKEN environment variable"
        context.error(f"❌ {error_msg}")
        return context.res.json({
            "success": False,
            "error": error_msg
        }, 500)
    
    context.log("✅ Found Replicate API token")
    
    try:
        # Prepare input parameters for Luma Ray
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
        context.log(f"Input parameters: {safe_json_dumps(input_params)}")
        
        # Create job document
        job = create_job_document(input_params['prompt'])
        job_id = job['$id']
        context.log(f"✅ Created job document with ID: {job_id}")
        
        # Start background processing
        asyncio.create_task(process_visualization_generation(context, job_id, input_params, start_time))
        
        # Return job ID immediately
        return context.res.json({
            "success": True,
            "message": "Visualization generation job created",
            "job_id": job_id
        })
            
    except Exception as e:
        context.error(f"❌ Setup error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": str(e)
        }, 500) 