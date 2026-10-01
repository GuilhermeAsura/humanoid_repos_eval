FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# System dependencies
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    libgl1 \
    libglx-mesa0 \
    libegl1 \
    libgles2 \
    libglfw3 \
    libglew2.2 \
    libosmesa6 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Python
# ------------------------------------------------------------
RUN python -m pip install --no-cache-dir --upgrade \
    pip \
    setuptools \
    wheel

# ------------------------------------------------------------
# uv
# ------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.local/bin:${PATH}"

# ------------------------------------------------------------
# MuJoCo Playground
# ------------------------------------------------------------
WORKDIR /workspace/mujoco_playground

# JAX with CUDA 12
RUN uv pip install --system --no-cache \
    "jax[cuda12]" \
    --index-url https://pypi.org/simple

# Runtime dependencies
RUN uv pip install --system --no-cache \
    mediapy \
    wandb \
    rscope

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
ENV MUJOCO_GL=egl
ENV JAX_DEFAULT_MATMUL_PRECISION=highest

# Do not inherit CUDA paths from unrelated containers.
ENV LD_LIBRARY_PATH=""

CMD ["/bin/bash"]