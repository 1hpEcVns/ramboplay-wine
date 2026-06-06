# ramboplay-wine

Nix flake environment for running [Ramboplay (蓝博玩)](https://client.ok-skins.com) — a Red Alert 2 / Yuri's Revenge game launcher — under Wine on Linux.

## Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled
- `ramboply.2.2.6_full.7z` archive placed in this directory

## Quick Start

```bash
# Enter the development shell (auto-extracts archive, installs .NET runtime)
nix develop

# Start the launcher backend
wine client/ramboplay.ra2.exe
```

The backend API server listens on **`http://localhost:3600`**.

The frontend is hosted at [client.ok-skins.com](https://client.ok-skins.com) and connects to the local backend.

## How It Works

Ramboplay is an ASP.NET Core 5.0 application:

- **Backend** (`client/ramboplay.ra2.exe`) — API server, WebSocket connections, game launching
- **Frontend** — SPA hosted remotely, loaded via WebView2 on Windows

The flake provisions:

| Component | Source |
|-----------|--------|
| Wine 11.0 | `wineWow64Packages.stable` |
| ASP.NET Core 5.0.17 | Microsoft CDN (auto-downloaded) |
| p7zip | Archive extraction |
| winetricks | Wine helper |

## Status

| Component | Working |
|-----------|---------|
| ASP.NET Core backend | ✅ |
| User authentication | ✅ |
| Map loading | ✅ |
| Server connections | ✅ |
| WebView2 (GPU renderer) | ⚠️ Crashes under Wine |
| Data Protection (DPAPI) | ⚠️ Fallback only |

The WebView2 embedded browser's GPU renderer crashes under Wine. Use the remote frontend in a native browser instead.

## Directory Layout

```
.
├── flake.nix          # Nix flake environment
├── flake.lock         # Locked inputs
├── .gitignore
├── client/            # Extracted launcher (gitignored)
├── .wine/             # Wine prefix (gitignored)
└── ramboply.*.7z      # Original archive (gitignored)
```

## License

This repository only contains the Nix environment. Ramboplay itself is proprietary software by LanBoWan (蓝博玩).
