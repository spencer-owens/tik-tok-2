# Peaceful Meditation API

FastAPI service for AI-powered meditation music generation.

## Setup

1. Install dependencies:
```bash
cd src
pip install -r requirements.txt
```

2. Set up environment variables:
- Copy `.env.example` to `.env`
- Fill in your API keys and configuration

## Development

Run the development server:
```bash
cd src
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`

## API Documentation

Once running, view the API documentation at:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Endpoints

### GET /
Health check endpoint

### POST /generate-music
Generate peaceful meditation music using Replicate's MusicGen model

## Testing

Run tests:
```bash
cd src
python3 test.py
```

## Deployment on Railway

1. Make sure your repository is structured correctly:
   ```
   api/
   ├── src/
   │   ├── main.py
   │   ├── test.py
   │   ├── requirements.txt
   │   ├── railway.toml
   │   └── .env.example
   └── README.md
   ```

2. Set up Railway:
   - Create a new project in Railway
   - Connect your GitHub repository
   - Set the root directory to `/api/src`
   - Add environment variables from `.env.example`

3. Deploy:
   - Railway will automatically detect the Python project
   - It will install dependencies from `requirements.txt`
   - The service will start using the command in `railway.toml`

4. Verify:
   - Check the deployment logs
   - Test the health check endpoint
   - Monitor the service metrics in Railway dashboard
