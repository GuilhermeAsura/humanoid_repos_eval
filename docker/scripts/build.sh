#!/usr/bin/env bash
# usage: docker/scripts/build.sh <base|holosoma|groot|luckyrobots|labrob|unitree-g1-control|all> [extra docker build args]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKER_DIR="${ROOT_DIR}/docker"
TARGET="${1:-all}"
shift || true

USER_ARGS=(--build-arg USER_UID="$(id -u)" --build-arg USER_GID="$(id -g)")

build_base() {
    docker build "${USER_ARGS[@]}" "$@" \
        -f "${DOCKER_DIR}/base.Dockerfile" \
        -t humanoid-base:latest \
        "${DOCKER_DIR}"
}

build_holosoma() {
    docker build "${USER_ARGS[@]}" "$@" \
        --build-context holosoma_src="${ROOT_DIR}/externals/holosoma" \
        -f "${DOCKER_DIR}/holosoma.Dockerfile" \
        -t humanoid-holosoma:latest \
        "${DOCKER_DIR}"
}

build_groot() {
    docker build "${USER_ARGS[@]}" "$@" \
        --build-context groot_src="${ROOT_DIR}/externals/GR00T-WholeBodyControl" \
        -f "${DOCKER_DIR}/groot.Dockerfile" \
        -t humanoid-groot:latest \
        "${DOCKER_DIR}"
}

build_luckyrobots() {
    docker build "${USER_ARGS[@]}" "$@" \
        -f "${DOCKER_DIR}/luckyrobots.Dockerfile" \
        -t humanoid-luckyrobots:latest \
        "${DOCKER_DIR}"
}

build_labrob() {
    docker build "${USER_ARGS[@]}" "$@" \
        -f "${DOCKER_DIR}/labrob.Dockerfile" \
        -t humanoid-labrob:latest \
        "${DOCKER_DIR}"
}

build_unitree_g1_control() {
    docker build "${USER_ARGS[@]}" "$@" \
        -f "${DOCKER_DIR}/unitree-g1-control.Dockerfile" \
        -t humanoid-unitree-g1-control:latest \
        "${DOCKER_DIR}"
}

case "${TARGET}" in
    base) build_base "$@" ;;
    holosoma) build_holosoma "$@" ;;
    groot) build_groot "$@" ;;
    luckyrobots) build_luckyrobots "$@" ;;
    labrob) build_labrob "$@" ;;
    unitree-g1-control) build_unitree_g1_control "$@" ;;
    all) build_base "$@" && build_holosoma "$@" && build_groot "$@" && build_luckyrobots "$@" && build_labrob "$@" && build_unitree_g1_control "$@" ;;
    *) echo "unknown target: ${TARGET} (base|holosoma|groot|luckyrobots|labrob|unitree-g1-control|all)" >&2; exit 1 ;;
esac
