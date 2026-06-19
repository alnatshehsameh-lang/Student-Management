# Deploy Notes (Render + Flutter Web + Nginx)

## Current Deployment Model
- Docker multi-stage build.
- Flutter web is built in the builder stage.
- Final image serves `/usr/share/nginx/html` using `nginx:alpine`.

## Files That Control Deploy Behavior
- `Dockerfile`
- `nginx.conf`
- `web/index.html`

## Important Build Settings
- Build command uses:
  - `flutter build web --release --pwa-strategy=none`
- Reason:
  - disables Flutter PWA service worker generation to avoid stale client bundles.

## Important Runtime Cache Settings (Nginx)
- `index.html`:
  - `Cache-Control: no-cache, no-store, must-revalidate`
- `flutter_bootstrap.js`:
  - `Cache-Control: no-cache, no-store, must-revalidate`
- `manifest.json` and `.json` startup/config files:
  - `Cache-Control: no-cache`
- `flutter_service_worker.js`:
  - `Cache-Control: no-cache, no-store, must-revalidate`
- SPA routing fallback remains:
  - `try_files $uri $uri/ /index.html;`

## Service Worker Cleanup
- `web/index.html` contains one-time cleanup logic that:
  - unregisters existing service workers
  - clears Cache Storage
  - reloads if a service worker still controls the page
- This helps migrate existing users away from old cached versions.

## Release Verification Checklist
1. Push to `main` and wait for Render deploy.
2. Confirm app starts without Nginx runtime errors.
3. In browser DevTools -> Network, verify headers:
   - `/index.html` => `no-cache, no-store, must-revalidate`
   - `/flutter_bootstrap.js` => `no-cache, no-store, must-revalidate`
   - `/manifest.json` => `no-cache`
4. In DevTools -> Application -> Service Workers, confirm no stale active worker.
5. Make a tiny UI text change and redeploy.
6. Confirm new version appears without asking users to clear cache manually.

## Troubleshooting
- If deploy builds but container exits immediately:
  - check Render logs for Nginx `[emerg]` syntax/runtime errors in `nginx.conf`.
- If deploy succeeds but users still see old UI:
  - confirm cache headers above are present in production response.
  - verify no active old service worker remains.
- If behavior seems unchanged after config updates:
  - run one Render deploy with "Clear build cache".
