# sandbox-world

Copyright 2025, jaggz.h {who is at} gmail.com. (But see LICENSE which is currently GPL).

## WARNING: This is the very first *untested* version.

A simple, secure, and flexible way to run Python (or other) projects in a sandboxed Docker environment, using overlays, so existing libs can be re-used without HUGE containers, while maintaining some semblance of 'safety'.

 - The project can write to the overlays (for when they need to update things).
 - The project can access exposed path mappings (handled by Docker)

## Feel free to submit pull requests.

## Features

- **Project directory isolation**: Code is mounted into `/prj` in the container
- **Overlay directories**: Temporary overlays for venvs, uv stores, etc. stored in `sandbox-overlay/` inside your project
- **Custom path mapping**: Expose host directories (for reading/writing) into the sandbox as you wish
- **Port exposing**: Map container ports for web apps or APIs (Gradio, Jupyter, etc.)
- **No outbound network by default**: (You may use your own firewall for this) **(I don't even know what this means. LLM said this. At present I didn't want to handle outbound network monitoring for the first version, relying on your own firewalling/network monitoring for it.)**
- **Reproducibility**: Generates a `sandbox-setup.sh` script to easily rerun the sandbox with the same options
- **Minimal base image**: Lightweight and efficient; you can swap to your preferred image

## Requirements

- [Docker](https://docs.docker.com/get-docker/) or compatible runtime
- Bash (for running the setup script)
- Python (optional, only if your project needs it)

## Brief Usage:

```bash
./sandbox-world \
  --prjdir ./myproj \
  --path output/:output-exposed/ \
  --overlay-venv \
  --port 7860:7860 \
  --cmd python3 main.py --foo=bar
```

## Full Usage:

### Usage: `sandbox-world [OPTIONS] --cmd ... [args...]`

Securely run your Python (or other) project inside a sandboxed Docker container, using overlays and explicit path mappings for controlled access to your host system.

### Options:
  `--prjdir DIR`
      *Required.*  
      Path to your project directory on the host.  
      This will be mounted as /prj inside the container.  
      WHY: Ensures all project code runs in a clean, isolated location.

  `--prjpath PATH`
      Path for the project directory inside the container. Default: /prj  
      WHY: Lets you customize the internal mount location if your project expects it elsewhere.

  `--path EXT:INT`
      Expose (bind-mount) a host path EXT into /prj/INT inside the container (read-write).  
      EXT must exist on the host before running.  
      WHY: Allows explicit, granular sharing of files or folders (e.g., output/ or data/) without exposing your whole system.  
      NOTE: INT can be a relative path under /prj, or a full absolute path in the container.

  `--ro-path EXT:INT`
      Same as --path, but mounted read-only.  
      WHY: Share data into the sandbox for reading, while guaranteeing it can't be modified.

  `--overlay-venv`
      Enable an overlay for your Python virtual environment (venv).  
      WHY: Lets the project install or update packages inside the sandbox without touching your real venv.   
      Safe for experiments, throwaway installs, or dependency isolation.

  `--no-venv`
      Disable venv overlay.  
      WHY: Use if you trust the project and want it to write directly to your venv.

  `--overlay-uv`
      Enable an overlay for your uv store (typically ~/.cache/uv).  
      WHY: Lets uv-based projects install packages without modifying your shared uv cache.  
      Prevents accidental pollution of global package storage.

  `--no-uv`
      Disable uv overlay.  
      WHY: For advanced users who want to share their actual uv store between projects.

  `--raw-venv`
      Mount your current venv directory directly (read-write), bypassing overlays.  
      WHY: Allows the project to modify the real venv. Use with caution!

  --raw-uv
      Mount the uv cache directory directly (read-write).  
      WHY: Share global uv packages between all sandboxes. Not recommended unless you know what you're doing.

  --port EXT:INT
      Expose host port EXT to container port INT.  
      WHY: Needed for local web apps (e.g., Gradio, Jupyter, Flask) to be accessible outside the sandbox.  
      Can be used multiple times for multiple ports.

  --cmd ...
      *Required.*  
      The command and arguments to run inside the container.  
      WHY: Defines the entrypoint. Everything after --cmd is executed as the main process inside the sandbox.

  -h, --help
      Show this help message and exit.

### Design Notes:
  - All overlays are stored in sandbox-overlay/ inside your project folder. 
    To fully clean up the sandbox, just delete this directory.
  - A script, sandbox-setup.sh, is generated in your project folder after each run.
    This script contains the exact command used to set up the sandbox, making it easy to rerun or share your setup.
  - All environment variables (HOME, USER, etc.) are sanitized inside the container so your real username and home directory are never exposed to the project.
  - By default, outbound network access is NOT provided.  
    WHY: For security, you should control network permissions using your firewall (e.g., OpenSnitch) as needed.

### Examples:
  # Run a project with venv overlay, exposing output/ as writable, and Gradio port 7860
  `./sandbox-world --prjdir ./myproj --path output/:output-exposed/ --overlay-venv --port 7860:7860 --cmd python3 main.py`

  # Share a data directory as read-only, and run a custom shell script
  `./sandbox-world --prjdir ./myproj --ro-path /mnt/datasets:/prj/data --cmd bash run-experiment.sh`

  # Clean up all sandbox artifacts:
  `rm -rf ./myproj/sandbox-overlay/`

For more info or updates, see README.md or open an issue on GitHub.

