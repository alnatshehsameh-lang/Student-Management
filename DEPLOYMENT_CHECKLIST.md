# Deployment Checklist

Use this checklist before pushing to `main` for Render deployment.

## 1) Pre-deploy sanity checks

- Ensure you are on the correct branch:
  - `git branch --show-current`
- Sync latest changes:
  - `git pull --rebase origin main`
- Resolve dependencies using lockfile:
  - `flutter pub get --enforce-lockfile`
- Run static analysis:
  - `dart analyze .`

## 2) Local build validation

- Validate web release build:
  - `flutter build web --release --no-wasm-dry-run`
- Validate Docker image build:
  - `docker build --progress=plain -f Dockerfile -t test-application-web:local .`
- Optional smoke test:
  - `docker run --rm -p 8080:80 --name test-app-local test-application-web:local`
  - Open `http://localhost:8080`

## 3) Commit and push

- Check intended files:
  - `git status --short`
- Commit with clear message:
  - `git add <files>`
  - `git commit -m "<message>"`
- Push to trigger Render deploy:
  - `git push origin main`

## 4) Post-deploy checks (Render)

- Confirm latest deploy is `Live`.
- Confirm build logs include successful web compile and image build.
- Open service URL and verify critical screens:
  - Student list
  - Attendance report
  - Weekly report screen

## 5) Fast rollback (if needed)

- Revert the bad commit:
  - `git revert <commit_sha>`
- Push revert:
  - `git push origin main`
- Confirm new Render deploy reaches `Live`.

## Notes

- Dockerfile is pinned to a specific Flutter version for deterministic CI builds.
- `flutter pub get --enforce-lockfile` prevents accidental dependency drift in CI.
- `--no-wasm-dry-run` removes non-blocking wasm warning noise from CI logs.
