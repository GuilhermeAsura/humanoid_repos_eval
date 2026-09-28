# humanoid_repos_eval

Zero-shot evaluation of open-source Unitree G1 locomotion stacks in MuJoCo. Each repo is added as a git submodule under `externals/` and runs in its own Docker container. Everything is driven from the host with `just`.

| repo | controller | status |
|---|---|---|
| [holosoma](https://github.com/amazon-far/holosoma) | RL (walking + whole-body tracking for dancing) | Runs; simulation is below real time on a laptop CPU, so the physics frequency is reduced to 500 Hz |
| [GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl) | RL legs + interpolated arms; MotionBricks (kinematic, generative) | Runs |
| [g1-manipulation-challenge](https://github.com/luckyrobots/g1-manipulation-challenge) | RL walker + right-arm reacher | Runs |
| [g1_locomotion](https://github.com/ioloizou/g1_locomotion) | Linear MPC + whole-body inverse dynamics (ROS Noetic) | Not built yet |
| [unitree_rl_gym](https://github.com/unitreerobotics/unitree_rl_gym/tree/main) | RL locomotion framework for legged and humanoid robots | Runs |

## requirements

- Linux with X11, Docker (with BuildKit) and [just](https://github.com/casey/just)
- NVIDIA GPU with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/) installed (`run.sh` uses `--runtime nvidia`)
- about 50 GB free disk; the `groot-wbc` image alone is 31 GB

## setup

```bash
git clone --recurse-submodules https://github.com/GuilhermeAsura/humanoid_repos_eval.git
cd humanoid_repos_eval/ && just build       # humanoid-base + holosoma, groot and luckyrobots images
```

GR00T keeps its models and meshes in Git LFS. Pull only what the demos need:

```bash
cd externals/GR00T-WholeBodyControl
git lfs pull --include="decoupled_wbc/sim2mujoco/**,decoupled_wbc/control/**,external_dependencies/unitree_sdk2_python/**"
git lfs pull --include="motionbricks/out/**,motionbricks/assets/skeletons/g1/meshes/**" --exclude=""   # ~2.3 GB
```

The full decoupled_wbc stack uses NVIDIA's prebuilt image: `docker pull nvgear/gr00t_wbc:latest`.

## usage

Start a container with `just up <name>` (`holosoma`, `groot`, `groot-wbc`, `luckyrobots`), then run the demo. Where two recipes are listed, run them in two terminals.

| demo | recipes |
|---|---|
| holosoma walk | `holosoma-sim` + `holosoma-policy` |
| holosoma dance | `holosoma-sim` + `holosoma-dance` |
| GR00T standalone walk | `groot-sim` |
| GR00T full control loop | `groot-wbc-sim` + `groot-wbc` |
| MotionBricks | `groot-motionbricks` |
| LuckyRobots | `luckyrobots-sim` |

`just --list` shows every recipe with its key bindings. `just down <name>` stops a container.

## notes

- Repo code is mounted into the containers, not copied, so `externals/` is what runs. Containers run as your user, except `groot-wbc`, which uses NVIDIA's root image.
- `run.sh` forces OpenGL onto the NVIDIA GPU with PRIME render offload. Without it, a hybrid Intel/NVIDIA laptop falls back to software rendering.
- Small glue code lives in `docker/`, so the upstream repos stay unmodified. For example, `docker/groot/run_gear_wbc.py` fixes the policy paths in GR00T's standalone demo.
