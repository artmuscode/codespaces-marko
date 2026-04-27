# Marko.build Devcontainer

A ready-to-use dev container for [Marko.build](https://marko.build) projects. Opens in VS Code Dev Containers or GitHub Codespaces and scaffolds a new Marko project automatically.

## What's included

- PHP (latest) + Composer
- Node.js (LTS) + Tailwind CSS
- MySQL or PostgreSQL (via Docker Compose)
- Redis (via Docker Compose)
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

4. Open on Mac Desktop/Windows/Linux `http://localhost:8000` in your browser when using VS Code Desktop you'll need to change "host" to 0.0.0.0 in config. 
5. When using Github Codespace goto PORTS tab and select the proper forwarded port (8000). Click to launch in browser.

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

## Docker Compose services

A `compose.yml` is automatically copied into your project on first build. It defines the available backing services:

| Service | Image | Default port |
|---|---|---|
| `mysql` | `mysql:8.0` | `3306` |
| `postgres` | `postgres:16-alpine` | `5432` |
| `redis` | `redis:7-alpine` | `6379` |

MySQL and Redis are enabled by default. PostgreSQL is commented out. To switch databases, open `compose.yml` in your project, comment out the `mysql` block, and uncomment `postgres` (and the `postgres-data` volume).

`marko up` will start whichever services are active.

Default database credentials:

| Field | Value |
|---|---|
| Host | `localhost` |
| Database | project name (e.g. `palettes`) |
| User | `marko` |
| Password | `marko` |
| Root password | `root` |

## Node / Tailwind CSS

A `package.json` is automatically copied into your project on first build with [Tailwind CSS v4](https://tailwindcss.com) included as a dev dependency. `npm install` runs automatically during setup.

To add further packages:

```bash
npm install <package>
```

## Rebuilding

To reset and re-scaffold from scratch, rebuild the container:

- VS Code: **Dev Containers: Rebuild Container**
- Codespaces: **Codespaces: Rebuild Container**
