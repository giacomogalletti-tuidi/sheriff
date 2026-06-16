# Deployment — host Sheriff online (free tier)

Sheriff ships as **one container**: the Dart server serves the Flutter web build
and the WebSocket endpoint on the same origin (`/` + `/ws`). This avoids CORS
and mixed-content issues.

Supported targets: **Render** (recommended for a quick playtest), **Fly.io**, or
any host that runs Docker with WebSocket support.

---

## Prerequisites

- A [GitHub](https://github.com) account with this repo pushed (public or private).
- For local image checks: [Docker Desktop](https://www.docker.com/products/docker-desktop/).

Environment variables used by the server:

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | `8080` | HTTP + WebSocket listen port (cloud hosts set this automatically). |
| `WEB_BUILD_DIR` | *(auto-detect)* | Path to `flutter build web` output; set to `/app/web` in the Dockerfile. |

---

## Test the Docker image locally

From the **repo root**:

```bash
docker build -t sheriff .
docker run --rm -p 8080:8080 -e PORT=8080 sheriff
```

Open http://localhost:8080 — create a room, open a second browser tab, join with
the room code.

---

## Deploy on Render (free)

Render's free web service sleeps after ~15 minutes without traffic. The first
request after sleep can take 30–60 seconds (cold start). Fine for playtesting
with friends.

### 1. Push the repo to GitHub

```bash
git add .
git commit -m "Add Docker deploy for online playtesting"
git push origin main
```

### 2. Create the web service

1. Go to [render.com](https://render.com) → **New** → **Web Service**.
2. Connect your GitHub repo.
3. Settings:
   - **Runtime**: Docker
   - **Dockerfile path**: `./Dockerfile` (repo root)
   - **Plan**: Free
   - **Health check path**: `/`
4. Click **Create Web Service**.

Render injects `PORT` automatically; no extra env vars are required.

Alternatively, use the included [`render.yaml`](../render.yaml) blueprint:
**New** → **Blueprint** → select the repo.

### 3. Play

When the deploy is live, open the URL Render gives you, e.g.

`https://sheriff-xxxx.onrender.com`

Share that link. Everyone uses the browser — no local server needed. Create a
room, share the 5-letter code, 3–5 players join and hit **Ready**.

The client picks `wss://<host>/ws` from the page URL when served over HTTPS.

### Render limitations (free tier)

- **Sleep on idle** — cold start after inactivity.
- **No persistence** — server restart drops all rooms and games (in-memory state).
- **Single instance** — enough for 3–5 players per room.

---

## Deploy on Fly.io (alternative)

Requires the [flyctl CLI](https://fly.io/docs/hands-on/install-flyctl/).

```bash
fly launch --no-deploy    # pick a region, don't deploy yet
fly deploy
```

`fly launch` creates `fly.toml`. Ensure the service exposes port 8080 internally;
Fly sets `PORT` and terminates TLS at the edge (`wss://` works).

Fly's free allowance is credit-based; check current limits on fly.io/pricing.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Page loads but lobby can't connect | WebSocket blocked or wrong URL | Confirm `/ws` upgrades on your host; on Render, use the **Web Service** (not Static Site). |
| `Web build not found` in browser | `WEB_BUILD_DIR` missing or empty image | Rebuild the Docker image; the Flutter stage must succeed. |
| Game lost after a while | Free tier sleep or deploy restart | Expected — state is in-memory only. |
| Works locally, fails on HTTPS | Mixed `ws://` on `https://` page | Use the single-host deploy (this Dockerfile); don't host the client separately on a static CDN without `wss://`. |

---

## What is not included yet

See [IMPROVEMENTS.md](IMPROVEMENTS.md) for follow-ups: structured logging,
`/health` endpoint, CI pipeline, Redis persistence, horizontal scaling.
