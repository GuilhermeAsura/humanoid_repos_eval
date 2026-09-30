ARG BASE_IMAGE=humanoid-base:latest
FROM ${BASE_IMAGE}

ARG USER_UID=1000
ARG USER_GID=1000

# node for the headless sim_node.mjs harness; the browser app itself only needs
# the stdlib http server (web/lib already vendors the mujoco wasm build, no npm install)
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
USER ${USER_UID}

RUN --mount=type=cache,target=/opt/uv/cache,uid=${USER_UID},gid=${USER_GID} \
    uv venv --python /usr/bin/python3.10 /opt/venvs/unitree-g1-control \
    && uv pip install --python /opt/venvs/unitree-g1-control/bin/python mujoco numpy scipy \
    && /opt/venvs/unitree-g1-control/bin/python -c "import mujoco, scipy; print('mujoco', mujoco.__version__)"

WORKDIR /workspace/unitree-g1-control
CMD ["sleep", "infinity"]
