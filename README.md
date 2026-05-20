# test_application

Flutter-based student management application with Supabase backend and web deployment via Docker/Render.

## Quick Start

- Install dependencies:
	- `flutter pub get --enforce-lockfile`
- Run app locally:
	- `flutter run`

## Web Build

- Build release web bundle:
	- `flutter build web --release --no-wasm-dry-run`

## Docker Build

- Build image locally:
	- `docker build --progress=plain -f Dockerfile -t test-application-web:local .`
- Run image locally:
	- `docker run --rm -p 8080:80 --name test-app-local test-application-web:local`

## Deployment

- Push to `main` to trigger Render deployment.
- Full pre/post deploy checklist: `DEPLOYMENT_CHECKLIST.md`
