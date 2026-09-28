#!/usr/bin/env bash
# usage: docker/scripts/run.sh <holosoma|groot|groot-wbc|luckyrobots>
# starts the repo container detached with gpu + x11; commands are run later via docker exec
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAME="${1:-holosoma}"

case "${NAME}" in
    holosoma)
        IMAGE=humanoid-holosoma:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/holosoma:/workspace/holosoma")
        ;;
    groot)
        IMAGE=humanoid-groot:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/GR00T-WholeBodyControl:/workspace/GR00T-WholeBodyControl")
        ;;
    groot-wbc)
        # upstream prebuilt image (ros2 humble, runs as root); paths mirror decoupled_wbc/docker/run_docker.sh
        IMAGE=nvgear/gr00t_wbc:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/GR00T-WholeBodyControl:/root/Projects/GR00T-WholeBodyControl"
            -w /root/Projects/GR00T-WholeBodyControl
            -e PYTHONPATH=/root/Projects/GR00T-WholeBodyControl
            -e DECOUPLED_WBC_DIR=/root/Projects/GR00T-WholeBodyControl
            -e PYTHONDONTWRITEBYTECODE=1
            -e NVIDIA_DRIVER_CAPABILITIES=all)
        ;;
    luckyrobots)
        IMAGE=humanoid-luckyrobots:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/g1-manipulation-challenge:/workspace/g1-manipulation-challenge")
        ;;
    *) echo "unknown container: ${NAME}" >&2; exit 1 ;;
esac

if [ "$(docker inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null)" = "true" ]; then
    echo "${NAME} already running"
    exit 0
fi
docker rm -f "${NAME}" >/dev/null 2>&1 || true

xhost +local:docker >/dev/null 2>&1 || echo "warning: xhost failed, gui may not open" >&2

# opengl on the nvidia gpu; on this hybrid (prime on-demand) laptop the default falls back to llvmpipe
docker run -d \
    --name "${NAME}" \
    --runtime nvidia \
    --network host \
    --ipc host \
    -e DISPLAY \
    -e __NV_PRIME_RENDER_OFFLOAD=1 \
    -e __GLX_VENDOR_LIBRARY_NAME=nvidia \
    -e QT_X11_NO_MITSHM=1 \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    "${MOUNTS[@]}" \
    "${IMAGE}" \
    sleep infinity

echo "${NAME} started"
