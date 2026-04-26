# Marko.build Devcontainer

A ready-to-use dev container for [Marko.build](https://marko.build) projects. Opens in VS Code Dev Containers or GitHub Codespaces and scaffolds a new Marko project automatically.

## What's included

- PHP (latest) + Composer
- Node.js (LTS)
- MySQL (client + server)
- Docker-in-Docker
- Port 8000 forwarded for the dev server

## Getting started

1. Open this repo in VS Code and choose **Reopen in Container** when prompted (or run `Dev Containers: Reopen in Container` from the command palette).
2. The container will build and automatically scaffold your Marko project. This takes a few minutes on first run.
3. Once ready, `cd` into your project and start the dev server:

```bash
cd palettes
marko up
```

4. Open `http://localhost:8000` in your browser when in VS Code Desktop devcontainer. Or if in Github Codespace the goto PORTS tab and select the proper forwarded port. Click to launch.

## Configuration

All project settings live in `.devcontainer/devcontainer.json` under `containerEnv`:

| Variable | Default | Description |
|---|---|---|
| `MARKO_PROJECT_NAME` | `palettes` | Folder name for the scaffolded project |
| `MARKO_INSTALL_MODE` | `skeleton` | `skeleton` or `framework` |
| `MARKO_PACKAGES` | see file | Space-separated Composer packages to install |

Change `MARKO_PROJECT_NAME` and rebuild — the project folder and shell PATH update automatically.

## Marko CLI

The `marko` CLI is available globally after the build:

```bash
marko        # list available commands
```

## Rebuilding

To reset and re-scaffold from scratch, rebuild the container:

- VS Code: **Dev Containers: Rebuild Container**
- Codespaces: **Codespaces: Rebuild Container**
