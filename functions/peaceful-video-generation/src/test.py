import os
import json
from datetime import datetime
from dotenv import load_dotenv
import replicate

# Load environment variables
load_dotenv()

class DateTimeEncoder(json.JSONEncoder):
    """Custom JSON encoder for datetime objects."""
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)

def safe_json_dumps(obj, indent=2):
    """Safely convert object to JSON string, handling datetime objects."""
    return json.dumps(obj, indent=indent, cls=DateTimeEncoder)

def main(context):
    """Test function focusing on music generation with detailed logging."""
    context.log("🎯 Test function entry point reached")
    
    # Log request details
    context.log(f"Request method: {context.req.method}")
    context.log(f"Request headers: {safe_json_dumps(dict(context.req.headers))}")
    context.log(f"Request body: {context.req.bodyText if hasattr(context.req, 'bodyText') else 'No body'}")
    
    # Log environment check
    replicate_api_key = os.getenv("REPLICATE_API_KEY")
    context.log(f"Replicate API key present: {bool(replicate_api_key)}")
    if not replicate_api_key:
        context.error("❌ REPLICATE_API_KEY not found in environment")
        return context.res.json({
            "success": False,
            "error": "Missing REPLICATE_API_KEY"
        })
    
    try:
        # Initialize Replicate client
        context.log("🔄 Initializing Replicate client")
        client = replicate.Client(api_token=replicate_api_key)
        context.log("✅ Replicate client initialized successfully")
        
        # Log available models (this will help us debug the 404)
        context.log("📚 Fetching model information")
        model = client.models.get("meta/musicgen")
        model_dict = {
            "name": model.name,
            "description": model.description,
            "owner": model.owner,
            "visibility": model.visibility,
            "latest_version": model.latest_version
        }
        context.log(f"Model info: {safe_json_dumps(model_dict)}")
        
        # Get latest version
        context.log("🔍 Getting latest model version")
        version = model.versions.list()[0]
        version_dict = {
            "id": version.id,
            "created_at": version.created_at,
            "cog_version": version.cog_version
        }
        context.log(f"Latest version info: {safe_json_dumps(version_dict)}")
        
        # Prepare generation parameters
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
        
        # Attempt music generation
        context.log("🎵 Starting music generation")
        output = version.predict(**input_params)
        context.log(f"✅ Music generation successful")
        context.log(f"Output: {safe_json_dumps(output)}")
        
        return context.res.json({
            "success": True,
            "output": output,
            "message": "Music generation test completed successfully"
        })
            
    except replicate.exceptions.ModelError as e:
        context.error(f"❌ Model error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": f"Model error: {str(e)}",
            "error_type": "ModelError"
        })
    except replicate.exceptions.ReplicateError as e:
        context.error(f"❌ Replicate error: {str(e)}")
        return context.res.json({
            "success": False,
            "error": f"Replicate error: {str(e)}",
            "error_type": "ReplicateError"
        })
    except Exception as e:
        context.error(f"❌ Unexpected error: {str(e)}")
        context.error(f"Error type: {type(e).__name__}")
        if hasattr(e, '__dict__'):
            context.error(f"Error attributes: {safe_json_dumps(e.__dict__)}")
        return context.res.json({
            "success": False,
            "error": str(e),
            "error_type": type(e).__name__
        }) 