import os
import json
import time
import asyncio
from datetime import datetime
from dotenv import load_dotenv
import replicate

# Load environment variables
load_dotenv()

def safe_json_dumps(obj):
    """Safely convert object to JSON string."""
    return json.dumps(obj, indent=2, default=str)

async def generate_music(context, input_params):
    """Async function to generate music using Replicate."""
    try:
        return replicate.run(
            "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
            input=input_params
        )
    except Exception as e:
        context.error(f"Music generation error: {str(e)}")
        raise

def main(context):
    """Main function handler for music generation."""
    start_time = time.time()
    context.log("🎯 Test function entry point reached")
    
    # Log request details
    context.log(f"Request method: {context.req.method}")
    context.log(f"Request path: {context.req.path}")
    context.log(f"Request headers: {safe_json_dumps(dict(context.req.headers))}")
    
    # Handle non-API requests (like favicon.png)
    if context.req.path and context.req.path != "/":
        return context.res.json({
            "success": False,
            "error": "Invalid endpoint. Please use the root path '/' for music generation.",
            "path": context.req.path
        }, 404)
    
    # Check environment
    replicate_token = os.getenv("REPLICATE_API_TOKEN")
    if not replicate_token:
        context.error("❌ REPLICATE_API_TOKEN not found in environment")
        return context.res.json({
            "success": False,
            "error": "Missing REPLICATE_API_TOKEN. Please set the REPLICATE_API_TOKEN environment variable."
        }, 500)
    
    context.log("✅ Found Replicate API token")
    
    try:
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
        context.log(f"Input parameters: {safe_json_dumps(input_params)}")
        
        # Start music generation
        context.log("🎵 Starting music generation")
        context.log(f"⏱️ Time elapsed before model run: {time.time() - start_time:.2f}s")
        
        # Execute music generation
        output = generate_music(context, input_params)
        
        # Log timing
        generation_time = time.time() - start_time
        context.log(f"⏱️ Time elapsed after model run: {generation_time:.2f}s")
        
        # Handle the output
        if isinstance(output, list):
            context.log("✅ Received list output")
            context.log(f"Number of outputs: {len(output)}")
            for i, item in enumerate(output):
                if hasattr(item, 'read'):
                    context.log(f"Output {i} is a file")
                else:
                    context.log(f"Output {i}: {str(item)}")
        else:
            context.log("✅ Received single output")
            context.log(f"Output: {str(output)}")
        
        # Return success response
        total_time = time.time() - start_time
        context.log(f"⏱️ Total execution time: {total_time:.2f}s")
        
        return context.res.json({
            "success": True,
            "output": str(output),
            "message": "Music generation started. Check the status URL for completion.",
            "execution_time_seconds": round(total_time, 2)
        })
            
    except replicate.exceptions.ModelError as e:
        context.error(f"❌ Model error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": f"Model error: {str(e)}",
            "error_type": "ModelError",
            "execution_time_seconds": round(time.time() - start_time, 2)
        }, 500)
    except replicate.exceptions.ReplicateError as e:
        context.error(f"❌ Replicate error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": f"Replicate error: {str(e)}",
            "error_type": "ReplicateError",
            "execution_time_seconds": round(time.time() - start_time, 2)
        }, 500)
    except Exception as e:
        context.error(f"❌ Unexpected error: {str(e)}")
        context.error(f"Error type: {type(e).__name__}")
        return context.res.json({
            "success": False,
            "error": str(e),
            "error_type": type(e).__name__,
            "execution_time_seconds": round(time.time() - start_time, 2)
        }, 500) 