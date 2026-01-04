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
- The Dockerfile uses `cirrusci/flutter:stable` to build the Flutter web app and serves using `nginx`.
- If Render's build environment lacks required tooling, Docker ensures reproducible builds.
- If you prefer Render Static Site, you must build `flutter build web` locally and push `build/web` as the static publish directory.
