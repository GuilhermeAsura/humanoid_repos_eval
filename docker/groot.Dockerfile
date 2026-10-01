ARG BASE_IMAGE=humanoid-base:latest
FROM ${BASE_IMAGE}

ARG USER_UID=1000
ARG USER_GID=1000

ENV GROOT_ROOT=/workspace/GR00T-WholeBodyControl

# only the sim2mujoco deps; decoupled_wbc[full] (lerobot, ray, ...) is not needed for the mujoco demo
RUN --mount=type=bind,from=groot_src,source=decoupled_wbc/sim2mujoco/requirements.txt,target=/tmp/sim2mujoco-requirements.txt \
    --mount=type=cache,target=/opt/uv/cache,uid=${USER_UID},gid=${USER_GID} \
    uv venv --python /usr/bin/python3.10 /opt/venvs/groot \
    && export UV_PYTHON=/opt/venvs/groot/bin/python \
    && uv pip install -r /tmp/sim2mujoco-requirements.txt torch pynput pyyaml \
    && /opt/venvs/groot/bin/python -c "import mujoco, onnxruntime, torch, yaml; print('mujoco', mujoco.__version__, 'torch', torch.__version__)"

# source is bind-mounted only for the editable install; at runtime the same path is a volume.
# root because setuptools writes egg-info into the (root-owned) bind mount. Uses its own cache id
# (not the shared /opt/uv/cache id every other build uses): this step runs as root, and uv/pip
# writes inside a root-run step land root-owned regardless of the mount's uid/gid args, which then
# blocks later uid-1000 builds (holosoma, luckyrobots, ...) from writing their own cache entries.
USER root
RUN --mount=type=bind,from=groot_src,source=motionbricks,target=/workspace/GR00T-WholeBodyControl/motionbricks,rw \
    --mount=type=cache,target=/opt/uv/cache,id=uv-cache-root,uid=${USER_UID},gid=${USER_GID} \
    uv venv --python /usr/bin/python3.10 /opt/venvs/motionbricks \
    && export UV_PYTHON=/opt/venvs/motionbricks/bin/python \
    && uv pip install -e "${GROOT_ROOT}/motionbricks" python-xlib \
    && /opt/venvs/motionbricks/bin/python -c "import torch, mujoco; print('torch', torch.__version__, 'mujoco', mujoco.__version__)" \
    && chown -R ${USER_UID}:${USER_GID} /opt/venvs/motionbricks
USER ${USER_UID}

COPY groot/run_gear_wbc.py /opt/glue/run_gear_wbc.py
COPY groot/run_motionbricks_demo.py /opt/glue/run_motionbricks_demo.py

WORKDIR ${GROOT_ROOT}
CMD ["sleep", "infinity"]
