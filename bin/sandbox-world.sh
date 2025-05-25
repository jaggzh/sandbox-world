#!/bin/bash
set -euo pipefail

prjdir=""
overlay_venv=1
overlay_uv=1
ports=()
paths=()
cmd=()
docker_image="debian:bookworm-slim"
rerun_args=()
found_cmd=0
rst=$'\033[0m'
bcya=$'\033[36;1m'
bgre=$'\033[32;1m'
bggre=$'\033[42;1m'
whi=$'\033[37;1m'
yel=$'\033[33;1m'

asect="$bcya" # Usage section name color
areq="$bggre$whi" # Usage section name color

# We pipe through less, but if user pipes, disable colors I guess.
if [[ ! -t 1 ]]; then
	asect=; areq=;
fi

usage() {
	cat<<EOT

${asect}Usage:$rst sandboxed-py [OPTIONS] --cmd ... [args...]

Securely run your Python (or other) project inside a sandboxed Docker container, using overlays and explicit path mappings for controlled access to your host system.

${asect}Options:$rst
  --prjdir DIR
      $areq*Required.*$rst
      Path to your project directory on the host.
      This will be mounted as /prj inside the container.
      WHY: Ensures all project code runs in a clean, isolated location.

  --prjpath PATH
      Path for the project directory inside the container. Default: /prj
      WHY: Lets you customize the internal mount location if your project expects it elsewhere.

  --path EXT:INT
      Expose (bind-mount) a host path EXT into /prj/INT inside the container (read-write).
      EXT must exist on the host before running.
      WHY: Allows explicit, granular sharing of files or folders (e.g., output/ or data/) without exposing your whole system.
      NOTE: INT can be a relative path under /prj, or a full absolute path in the container.

  --ro-path EXT:INT
      Same as --path, but mounted read-only.
      WHY: Share data into the sandbox for reading, while guaranteeing it can't be modified.

  --overlay-venv
      Enable an overlay for your Python virtual environment (venv).
      WHY: Lets the project install or update packages inside the sandbox without touching your real venv. 
      Safe for experiments, throwaway installs, or dependency isolation.

  --no-venv
      Disable venv overlay.
      WHY: Use if you trust the project and want it to write directly to your venv.

  --overlay-uv
      Enable an overlay for your uv store (typically ~/.cache/uv).
      WHY: Lets uv-based projects install packages without modifying your shared uv cache.
      Prevents accidental pollution of global package storage.

  --no-uv
      Disable uv overlay.
      WHY: For advanced users who want to share their actual uv store between projects.

  --raw-venv
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
      $areq*Required.*$rst
      The command and arguments to run inside the container.
      WHY: Defines the entrypoint. Everything after --cmd is executed as the main process inside the sandbox.

  -h, --help
      Show this help message and exit.

Design Notes:
  - All overlays are stored in sandbox-overlay/ inside your project folder. 
    To fully clean up the sandbox, just delete this directory.
  - A script, sandbox-setup.sh, is generated in your project folder after each run.
    This script contains the exact command used to set up the sandbox, making it easy to rerun or share your setup.
  - All environment variables (HOME, USER, etc.) are sanitized inside the container so your real username and home directory are never exposed to the project.
  - By default, outbound network access is NOT provided.
    WHY: For security, you should control network permissions using your firewall (e.g., OpenSnitch) as needed.

${asect}Examples:$rst
  # Run a project with venv overlay, exposing output/ as writable, and Gradio port 7860
  ./sandboxed-py --prjdir ./myproj --path output/:output-exposed/ --overlay-venv --port 7860:7860 --cmd python3 main.py

  # Share a data directory as read-only, and run a custom shell script
  ./sandboxed-py --prjdir ./myproj --ro-path /mnt/datasets:/prj/data --cmd bash run-experiment.sh

  # Clean up all sandbox artifacts:
  rm -rf ./myproj/sandbox-overlay/

For more info or updates, see README.md or open an issue on GitHub!

EOT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prjdir)
      prjdir="$2"; shift 2; rerun_args+=("--prjdir" "$prjdir") ;;
    --path)
      paths+=("$2"); shift 2; rerun_args+=("--path" "$2") ;;
    --port)
      ports+=("$2"); shift 2; rerun_args+=("--port" "$2") ;;
    --overlay-venv)
      overlay_venv=1; rerun_args+=("--overlay-venv"); shift ;;
    --no-venv)
      overlay_venv=0; rerun_args+=("--no-venv"); shift ;;
    --overlay-uv)
      overlay_uv=1; rerun_args+=("--overlay-uv"); shift ;;
    --no-uv)
      overlay_uv=0; rerun_args+=("--no-uv"); shift ;;
    --cmd)
      found_cmd=1; shift
      cmd=("$@")
      rerun_args+=("--cmd" "${cmd[@]}")
      break
      ;;
    -h|--help) usage | less -R; exit ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$prjdir" ]]; then
  echo "Must specify --prjdir"
  exit 1
fi

if [[ $found_cmd -eq 0 ]]; then
  echo "Must specify --cmd (entrypoint to run inside container)"
  exit 1
fi

mkdir -p "$prjdir/sandbox-overlay"

for mapping in "${paths[@]}"; do
  ext="${mapping%%:*}"
  if [[ ! -e "$ext" ]]; then
    echo "Error: Host path $ext does not exist (required for --path)"
    exit 1
  fi
done

# Write rerun script safely
{
  echo "#!/bin/bash"
  printf 'exec %q ' "$0"
  for arg in "${rerun_args[@]}"; do
    printf '%q ' "$arg"
  done
  echo
} > "$prjdir/sandbox-setup.sh"
chmod +x "$prjdir/sandbox-setup.sh"

# Compose Docker volume args
vols=(-v "$prjdir:/prj:ro" -v "$prjdir/sandbox-overlay:/sandbox-overlay")
[[ $overlay_venv -eq 1 ]] && vols+=(-v "$prjdir/sandbox-overlay/venv:/venv-overlay")
[[ $overlay_uv -eq 1 ]] && vols+=(-v "$prjdir/sandbox-overlay/uv:/uv-overlay")
for mapping in "${paths[@]}"; do
  ext="${mapping%%:*}"
  int="${mapping#*:}"
  vols+=(-v "$PWD/$ext:/prj/$int")
done

# Compose Docker port args
port_args=()
for p in "${ports[@]}"; do
  port_args+=(-p "$p")
done

# Docker run
docker run --rm \
  "${vols[@]}" \
  "${port_args[@]}" \
  -e HOME=/sandbox \
  -e USER=sandbox \
  -w /prj \
  "$docker_image" \
  "${cmd[@]}"
