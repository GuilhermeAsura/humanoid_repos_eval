FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# ==================================================
# System dependencies
# ==================================================
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    cmake \
    libgl1 \
    libegl1 \
    libglfw3 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxrandr2 \
    libxi6 \
    libxcursor1 \
    libxinerama1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ==================================================
# Miniconda
# ==================================================
RUN wget -q \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

ENV PATH="/opt/conda/bin:${PATH}"

# ==================================================
# Unitree RL environment
# Python 3.8
# ==================================================
RUN conda tos accept --override-channels \
        --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels \
        --channel https://repo.anaconda.com/pkgs/r && \
    conda create -y -n unitree-rl python=3.8 && \
    conda clean -afy

ENV PATH="/opt/conda/envs/unitree-rl/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/conda/envs/unitree-rl/lib:${LD_LIBRARY_PATH}"

# ==================================================
# PyTorch 2.3.1 + CUDA 12.1
# Official Unitree configuration
# ==================================================
RUN conda install -y -n unitree-rl \
    pytorch==2.3.1 \
    torchvision==0.18.1 \
    torchaudio==2.3.1 \
    pytorch-cuda=12.1 \
    -c pytorch \
    -c nvidia && \
    conda clean -afy

# ==================================================
# Isaac Gym
# The build context is the Isaac Gym directory
# ==================================================
COPY . /opt/isaacgym

RUN cd /opt/isaacgym/python && \
    pip install -e .

# ==================================================
# rsl_rl v1.0.2
# ==================================================
RUN git clone \
    --branch v1.0.2 \
    --depth 1 \
    https://github.com/leggedrobotics/rsl_rl.git \
    /opt/rsl_rl

RUN cd /opt/rsl_rl && \
    pip install -e .

# ==================================================
# Unitree RL Gym dependencies
# ==================================================
RUN pip install \
    "numpy==1.20" \
    matplotlib \
    tensorboard \
    "mujoco==3.2.3" \
    pyyaml

# ==================================================
# Workspace
# ==================================================
WORKDIR /workspace/unitree_rl_gym

# ==================================================
# NVIDIA Container Toolkit
# ==================================================
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

CMD ["/bin/bash"]
