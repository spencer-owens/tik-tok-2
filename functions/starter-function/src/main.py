import os
from appwrite.client import Client
from appwrite.exception import AppwriteException
from appwrite.services.users import Users

def main(context):
    # Simple test response
    return context.res.json({
        "message": "Hello from Appwrite Function!",
        "status": "success"
    }) 