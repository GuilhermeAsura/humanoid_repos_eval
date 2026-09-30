#!/usr/bin/env bash
# usage: docker/scripts/run.sh <holosoma|groot|groot-wbc|luckyrobots|g1-locomotion|wb-humanoid-mpc|labrob|unitree-g1-control|romoco>
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
    g1-locomotion)
        # upstream image (ros noetic, runs as root); mount over its baked-in copy of g1_locomotion (main branch)
        # unlike the other images, opensot isn't built FROM humanoid-base, so it doesn't inherit
        # NVIDIA_VISIBLE_DEVICES=all from there; without it the nvidia runtime hook injects no
        # driver libraries at all and mujoco/rviz silently fall back to llvmpipe software rendering
        IMAGE=opensot:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/g1_locomotion:/home/forest_ws/src/g1_locomotion"
            -e PYTHONDONTWRITEBYTECODE=1
            -e NVIDIA_VISIBLE_DEVICES=all
            -e NVIDIA_DRIVER_CAPABILITIES=all)
        ;;
    wb-humanoid-mpc)
        # upstream image (ros 2 jazzy, runs as root); mount over its baked-in copy of the repo.
        # same NVIDIA_VISIBLE_DEVICES gap as g1-locomotion: not built FROM humanoid-base, so the
        # nvidia runtime hook injects no driver libraries without it (mujoco/rviz fall back to
        # llvmpipe software rendering)
        IMAGE=wb-humanoid-mpc:dev
        MOUNTS=(-v "${ROOT_DIR}/externals/wb_humanoid_mpc:/wb_humanoid_mpc_ws/src/wb_humanoid_mpc"
            -w /wb_humanoid_mpc_ws/src/wb_humanoid_mpc
            -e PYTHONDONTWRITEBYTECODE=1
            -e NVIDIA_VISIBLE_DEVICES=all
            -e NVIDIA_DRIVER_CAPABILITIES=all)
        ;;
    labrob)
        IMAGE=humanoid-labrob:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/labrob_mujoco_environment:/workspace/labrob_mujoco_environment")
        ;;
    unitree-g1-control)
        IMAGE=humanoid-unitree-g1-control:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/unitree-g1-control:/workspace/unitree-g1-control")
        ;;
    romoco)
        # upstream image (ros 2 humble, image built by externals/RoMoCo/docker/build.sh); its
        # Dockerfile bakes a non-root "docker" user and expects the repo mounted at
        # /home/docker/RoMoCo, unlike the /workspace/<repo> convention used above
        IMAGE=biped-sim:latest
        MOUNTS=(-v "${ROOT_DIR}/externals/RoMoCo:/home/docker/RoMoCo"
            --user docker
            -e HOME=/home/docker
            -w /home/docker/RoMoCo
            -e NVIDIA_VISIBLE_DEVICES=all
            -e NVIDIA_DRIVER_CAPABILITIES=all)
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
