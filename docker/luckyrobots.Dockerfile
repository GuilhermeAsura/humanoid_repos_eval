ARG BASE_IMAGE=humanoid-base:latest
FROM ${BASE_IMAGE}

ARG USER_UID=1000
ARG USER_GID=1000

# qt/xcb runtime for opencv-python's imshow camera windows
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 libsm6 libice6 libfontconfig1 libdbus-1-3 \
        libxcb1 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
        libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 libxcb-xkb1 fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
USER ${USER_UID}

RUN --mount=type=cache,target=/opt/uv/cache,uid=${USER_UID},gid=${USER_GID} \
    uv venv --python /usr/bin/python3.10 /opt/venvs/luckyrobots \
    && uv pip install --python /opt/venvs/luckyrobots/bin/python mujoco onnxruntime numpy opencv-python \
    && /opt/venvs/luckyrobots/bin/python -c "import mujoco, onnxruntime, cv2; print('mujoco', mujoco.__version__, 'cv2', cv2.__version__)" \
    && ln -s /usr/share/fonts/truetype/dejavu /opt/venvs/luckyrobots/lib/python3.10/site-packages/cv2/qt/fonts

WORKDIR /workspace/g1-manipulation-challenge
CMD ["sleep", "infinity"]
