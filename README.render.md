Deployment to Render (Docker)

1. Ensure your repo is pushed to GitHub/GitLab (branch `main` or change `render.yaml`).

2. Render will detect `render.yaml` and use the Dockerfile; if not, create a new Web Service on Render and connect your repository, choose "Docker" and the root Dockerfile.

Local test with Docker (PowerShell):

```powershell
# Build image locally
docker build -t test-application-web .

# Run container
docker run --rm -p 8080:80 test-application-web

# Then open http://localhost:8080
```

Notes:
- The Dockerfile now uses a multi-stage build: Flutter compiles the web app from source, then nginx serves the generated files.
- You do not need to commit `build/web` for Docker-based Render deployments.
- If you prefer Render Static Site (non-Docker), then you must build `flutter build web` and configure a publish directory.
