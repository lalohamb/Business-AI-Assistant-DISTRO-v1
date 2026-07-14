# Open WebUI Branding

## Overview

Custom CSS theming and UI title for the Business AI Assistant dashboard.

## Files

| File | Purpose |
|------|---------|
| `dashboard/custom.css` | CSS source (edit this to change theme) |
| `admin/apply_branding.sh` | Deploys CSS + title into running container |
| `admin/install.sh` Phase 12B | Applies branding during install |
| `admin/post_install_verify.sh` Test 9C | Validates branding is active |

## How It Works

Open WebUI's `index.html` includes `<link rel="stylesheet" href="/static/custom.css">`.
The CSS file overrides Tailwind CSS custom properties (`--color-white`, `--color-gray-*`)
at the `:root` level, which cascades to all background utility classes without touching
individual components.

The file lives at `/app/backend/open_webui/static/custom.css` inside the container.
Since this path is inside the image layer (not a volume), it resets on container
recreation. The `apply_branding.sh` script re-deploys it.

## Usage

### Edit the theme

```bash
nano dashboard/custom.css
./admin/apply_branding.sh
# Hard-refresh browser (Ctrl+Shift+R)
```

### Available color variables

| Variable | Controls | Default override |
|----------|----------|-----------------|
| `--color-white` | Main background (light mode) | `#89CFF0` (baby blue) |
| `--color-gray-50` | Secondary background (light) | `#a8dcf4` |
| `--color-gray-850` | Main background (dark mode) | `#1f4050` |
| `--color-gray-900` | Secondary background (dark) | `#1a3a4a` |
| `--color-gray-950` | Deepest background (dark) | `#0f2a38` |

### Disable branding

Empty the CSS file:
```bash
> dashboard/custom.css
./admin/apply_branding.sh
```

## After Updates / Container Recreation

Branding is lost when:
- Container is recreated (`docker rm` + `docker run`)
- Open WebUI image is updated (`docker pull`)
- Container restarts (the `index.html` patch is lost)

**Fix (one command):**
```bash
./admin/apply_branding.sh
```

This is NOT automated on restart. Run it manually after any container
recreation, or re-run `install.sh` which calls it in Phase 12B.

## Verification

```bash
./admin/post_install_verify.sh
```

Test 9C checks:
1. `dashboard/custom.css` exists on host
2. CSS is deployed inside the container
3. `crossorigin` attribute is removed from `index.html`
4. CSS is served at `http://localhost:3000/static/custom.css`

If any check fails, the verify script auto-repairs by calling `apply_branding.sh`.

## Technical Notes

- The `crossorigin="use-credentials"` attribute on the CSS link tag causes browsers
  to require CORS headers. Since the backend doesn't send them for static files,
  the CSS silently fails to load. The branding script strips this attribute.
- The `ui.name` config key in SQLite sets the title shown after login.
  The unauthenticated page title comes from the `WEBUI_NAME` env var (which
  appends "(Open WebUI)" to any custom value — this is hardcoded in the image).
- The `ui.custom_css` config key exists in the database but the v0.10.x frontend
  does not read or apply it. The static file approach is the only working method.
