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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prjdir)
      prjdir="$2"; shift 2; rerun_args+=("--prjdir" "$prjdir")
      ;;
    --path)
      paths+=("$2"); shift 2; rerun_args+=("--path" "$2")
      ;;
    --port)
      ports+=("$2"); shift 2; rerun_args+=("--port" "$2")
      ;;
    --overlay-venv)
      overlay_venv=1; rerun_args+=("--overlay-venv"); shift
      ;;
    --no-venv)
      overlay_venv=0; rerun_args+=("--no-venv"); shift
      ;;
    --overlay-uv)
      overlay_uv=1; rerun_args+=("--overlay-uv"); shift
      ;;
    --no-uv)
      overlay_uv=0; rerun_args+=("--no-uv"); shift
      ;;
    --cmd)
      found_cmd=1; shift
      cmd=("$@")
      rerun_args+=("--cmd" "${cmd[@]}")
      break
      ;;
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
