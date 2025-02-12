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
    """Async function to handle music generation."""
    try:
        return replicate.run(
            "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
            input=input_params
        )
    except Exception as e:
        context.error(f"Error in generate_music: {str(e)}")
        raise

async def main(context):
    """Test function focusing on music generation with detailed logging."""
    start_time = time.time()
    context.log("🎯 Test function entry point reached")
    
    # Log request details
    context.log(f"Request method: {context.req.method}")
    context.log(f"Request path: {context.req.path}")
    context.log(f"Request headers: {safe_json_dumps(dict(context.req.headers))}")
    
    # Handle non-API requests
    if context.req.path and context.req.path != "/":
        context.error(f"❌ Invalid path requested: {context.req.path}")
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
        
        # Run the model using replicate.run()
        context.log("🎵 Starting music generation")
        context.log(f"⏱️ Time elapsed before model run: {time.time() - start_time:.2f}s")
        
        # Use asyncio.create_task to handle the long-running operation
        try:
            # Create a task with timeout
            task = asyncio.create_task(generate_music(context, input_params))
            output = await asyncio.wait_for(task, timeout=25.0)  # Set timeout to 25s to ensure we stay under 30s limit
            
            context.log(f"⏱️ Time elapsed after model run: {time.time() - start_time:.2f}s")
            
            # Handle the output based on type
            if isinstance(output, list):
                context.log("✅ Received list output")
                context.log(f"Number of outputs: {len(output)}")
                for i, item in enumerate(output):
                    if hasattr(item, 'read'):  # FileOutput object
                        context.log(f"Output {i} is a file")
                    else:
                        context.log(f"Output {i}: {str(item)}")
            else:
                context.log("✅ Received single output")
                context.log(f"Output: {str(output)}")
            
            total_time = time.time() - start_time
            context.log(f"⏱️ Total execution time: {total_time:.2f}s")
            
            return context.res.json({
                "success": True,
                "output": str(output),
                "message": "Music generation test completed successfully",
                "execution_time_seconds": round(total_time, 2)
            })
            
        except asyncio.TimeoutError:
            context.error("❌ Operation timed out")
            return context.res.json({
                "success": False,
                "error": "Operation timed out. Please try again.",
                "error_type": "TimeoutError",
                "execution_time_seconds": round(time.time() - start_time, 2)
            }, 408)
            
    except replicate.exceptions.ModelError as e:
        context.error(f"❌ Model error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": f"Model error: {str(e)}",
            "error_type": "ModelError",
            "execution_time_seconds": round(time.time() - start_time, 2)
        })
    except replicate.exceptions.ReplicateError as e:
        context.error(f"❌ Replicate error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": f"Replicate error: {str(e)}",
            "error_type": "ReplicateError",
            "execution_time_seconds": round(time.time() - start_time, 2)
        })
    except Exception as e:
        context.error(f"❌ Unexpected error: {str(e)}")
        context.error(f"Error type: {type(e).__name__}")
        return context.res.json({
            "success": False,
            "error": str(e),
            "error_type": type(e).__name__,
            "execution_time_seconds": round(time.time() - start_time, 2)
        }) 