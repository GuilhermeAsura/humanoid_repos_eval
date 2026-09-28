ARG BASE_IMAGE=humanoid-base:latest
FROM ${BASE_IMAGE}

ARG INSTALL_WARP=false
ARG USER_UID=1000
ARG USER_GID=1000

ENV HOLOSOMA_ROOT=/workspace/holosoma

# source is bind-mounted only for the editable installs; at runtime the same path is a volume
RUN --mount=type=bind,from=holosoma_src,target=/workspace/holosoma \
    --mount=type=cache,target=/opt/uv/cache,uid=${USER_UID},gid=${USER_GID} \
    uv venv --python /usr/bin/python3.10 /opt/venvs/hsmujoco \
    && export UV_PYTHON=/opt/venvs/hsmujoco/bin/python \
    && uv pip install 'mujoco>=3.0.0' mujoco-python-viewer \
        -e "${HOLOSOMA_ROOT}/src/holosoma[unitree,booster]" \
    && uv pip install 'numpy>=1.23.5,<2' \
    && if [ "${INSTALL_WARP}" = "true" ]; then uv pip install 'mujoco-warp[cuda]'; fi \
    && /opt/venvs/hsmujoco/bin/python -c "import mujoco, mujoco_viewer, holosoma; print('mujoco', mujoco.__version__)"

RUN --mount=type=bind,from=holosoma_src,target=/workspace/holosoma \
    --mount=type=cache,target=/opt/uv/cache,uid=${USER_UID},gid=${USER_GID} \
    uv venv --python /usr/bin/python3.10 /opt/venvs/hsinference \
    && export UV_PYTHON=/opt/venvs/hsinference/bin/python \
    && uv pip install -e "${HOLOSOMA_ROOT}/src/holosoma_inference[unitree,booster]" 'pin>=3.8.0' \
    && /opt/venvs/hsinference/bin/python -c "import holosoma_inference, pinocchio; print('pinocchio', pinocchio.__version__)"

WORKDIR ${HOLOSOMA_ROOT}
CMD ["sleep", "infinity"]
