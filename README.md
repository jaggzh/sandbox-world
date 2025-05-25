# sandbox-world

Copyright 2025, jaggz.h {who is at} gmail.com. (But see LICENSE which is currently GPL).

## WARNING: This is the very first *untested* version.

A simple, secure, and flexible way to run Python (or other) projects in a sandboxed Docker environment, using overlays and path mappings to keep your host system clean and safe.

## Features

- **Project directory isolation**: Code is mounted into `/prj` in the container
- **Overlay directories**: Temporary overlays for venvs, uv stores, etc. stored in `sandbox-overlay/` inside your project
- **Custom path mapping**: Expose host directories (for reading/writing) into the sandbox as you wish
- **Port exposing**: Map container ports for web apps or APIs (Gradio, Jupyter, etc.)
- **No outbound network by default**: (You may use your own firewall for this)
- **Reproducibility**: Generates a `sandbox-setup.sh` script to easily rerun the sandbox with the same options
- **Minimal base image**: Lightweight and efficient; you can swap to your preferred image

## Requirements

- [Docker](https://docs.docker.com/get-docker/) or compatible runtime
- Bash (for running the setup script)
- Python (optional, only if your project needs it)

## Usage

```bash
./sandbox-world \
  --prjdir ./myproj \
  --path output/:output-exposed/ \
  --overlay-venv \
  --port 7860:7860 \
  --cmd python3 main.py --foo=bar
