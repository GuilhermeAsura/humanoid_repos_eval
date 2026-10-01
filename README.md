# humanoid_repos_eval

Zero-shot evaluation of open-source Unitree G1 locomotion stacks in MuJoCo. Each repo is added as a git submodule under `externals/` and runs in its own Docker container. Everything is driven from the host with `just`.

| repo | controller | status |
|---|---|---|
| [holosoma](https://github.com/amazon-far/holosoma) | RL (walking + whole-body tracking for dancing) | Runs; simulation is below real time on a laptop CPU, so the physics frequency is reduced to 500 Hz |
| [GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl) | RL legs + interpolated arms; MotionBricks (kinematic, generative) | Runs |
| [g1-manipulation-challenge](https://github.com/luckyrobots/g1-manipulation-challenge) | RL walker + right-arm reacher | Runs |
| [g1_locomotion](https://github.com/ioloizou/g1_locomotion) | Linear MPC + whole-body inverse dynamics (ROS Noetic) | Runs, ~19x below real time (needs `NVIDIA_VISIBLE_DEVICES=all`, see report — its image doesn't inherit that from a base like the others) |
| [unitree_rl_gym](https://github.com/unitreerobotics/unitree_rl_gym/tree/main) | RL locomotion framework for legged and humanoid robots | Runs |
| [wb_humanoid_mpc](https://github.com/manumerous/wb_humanoid_mpc) | Nonlinear whole-body/centroidal MPC via ocs2 (ROS 2 Jazzy) | Centroidal MPC runs well; whole-body dynamics MPC launches but thrashes instead of walking (likely missing real-time thread scheduling in the container, unconfirmed). First launch pays a one-time CppAD codegen cost (~30-40 min here, not the README's 5-15). See report |
| [labrob_mujoco_environment](https://github.com/matteogoddi/labrob_mujoco_environment) | Offline footstep planner + IS-MPC (LIP) + whole-body QP, no RL/ROS (plain CMake/C++) | Walks stably on a fixed straight-line plan, pronounced pendulum-like side-to-side sway (expected for a LIP-based gait). Push recovery tested and doesn't work: any scripted external force, down to a light 8N nudge, destabilizes the controller into a physics-breaking NaN rather than a fall or recovery — footstep correction for disturbances is an unimplemented TODO upstream. Needed mujoco/hpipm pinned to specific old versions/commits to match the code's API calls, not documented anywhere upstream. Also implements cooperative-carrying (hand admittance), untested. See report |
| [RoMoCo](https://github.com/min-dai/RoMoCo) | Reduced-order planner (ALIP/H-LIP/MLIP/DCM) + whole-body TSC-QP, no RL (ROS 2 Humble) | Builds and runs; all 3 nodes (MuJoCo interface, controller, on-screen radio GUI) come up cleanly and the pinocchio model loads correctly. Not driven to an actual walk here — the sim starts paused by design (press Spacebar in the MuJoCo window to unpause, then use the on-screen GUI to send stand/walk), which looks like a stuck "waiting for proprioception" hang but isn't. Needed Pinocchio pinned to v3.9.0 (upstream's version pin was dead due to a Dockerfile comment silently swallowing it) and `CMAKE_PREFIX_PATH` re-exported for `docker exec`. See report |

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

Start a container with `just up <name>` (`holosoma`, `groot`, `groot-wbc`, `luckyrobots`, `g1-locomotion`, `wb-humanoid-mpc`, `labrob`, `romoco`), then run the demo. Where two recipes are listed, run them in two terminals.

| demo | recipes |
|---|---|
| holosoma walk | `holosoma-sim` + `holosoma-policy` |
| holosoma dance | `holosoma-sim` + `holosoma-dance` |
| GR00T standalone walk | `groot-sim` |
| GR00T full control loop | `groot-wbc-sim` + `groot-wbc` |
| MotionBricks | `groot-motionbricks` |
| LuckyRobots | `luckyrobots-sim` |
| g1_locomotion walk | `g1-loco-build` (once) + `g1-loco-sim` |
| wb_humanoid_mpc centroidal (dummy) | `wb-mpc-build` (once) + `wb-mpc-centroidal-dummy` |
| wb_humanoid_mpc whole-body (dummy) | `wb-mpc-build` (once) + `wb-mpc-wb-dummy` |
| labrob_mujoco_environment walk | `labrob-build` (once) + `labrob-sim` |
| RoMoCo G1 (needs Spacebar in the MuJoCo window to unpause, then the on-screen radio GUI for commands) | `romoco-image` (once) + `romoco-build` (once) + `romoco-sim` |

`just --list` shows every recipe with its key bindings. `just down <name>` stops a container.

## notes

- Repo code is mounted into the containers, not copied, so `externals/` is what runs. Containers run as your user, except `groot-wbc`, which uses NVIDIA's root image.
- `run.sh` forces OpenGL onto the NVIDIA GPU with PRIME render offload. Without it, a hybrid Intel/NVIDIA laptop falls back to software rendering.
- Small glue code lives in `docker/`, so the upstream repos stay unmodified. For example, `docker/groot/run_gear_wbc.py` fixes the policy paths in GR00T's standalone demo.


----

## Results

**Scope:** zero-shot evaluation of open-source Unitree G1 locomotion stacks, running pretrained policies or analytical controllers in MuJoCo simulation — no training performed as part of this evaluation.

The selected repositories were ranked across three axes:
- **RL-based**: most versatile and high-performance learned policy for locomotion.
- **Model-based**: most precise and fluid analytical controller for locomotion.
- **Training environment**: best candidate environment for future RL training.

An initial list of 26 humanoid locomotion repositories was compiled and filtered down to the ones in this repo, based on compatibility with the G1, ability to actually run, reproducibility, zero-shot inference capability, and simulator used. One repo was picked as the best fit for each axis below; the rest are summarized in [Other tested repos](#other-tested-repos).

### RL-based: 

#### GR00T-WholeBodyControl

**What it is:** NVIDIA's repository bundling three components for G1 whole-body control: Decoupled WBC (RL legs + IK/interpolated arms), GEAR-SONIC (a single RL policy that tracks arbitrary whole-body motion), and MotionBricks (a generative motion model). Decoupled WBC's standalone and full control-loop demos, and MotionBricks, were run here; GEAR-SONIC was not tried.

**How it works:**
- Decoupled WBC splits the body in two: an RL policy drives the legs/waist for balance and velocity tracking (`navigate_cmd`, `base_height_command`); the arms don't use RL and instead follow a target pose via interpolation or inverse kinematics.
- The full control loop runs the MuJoCo sim and the ROS 2 control loop as separate processes, bridged over the Unitree SDK — running them in the same process serializes on Python's GIL and tanks the loop rate.
- GEAR-SONIC (not tested here) is trained with PPO in Isaac Lab on motion-tracking: encoders turn a reference motion into a 64-dim quantized latent token, a decoder turns the token into joint targets, and a separate kinematic planner (ONNX) turns a high-level command into the reference motion the tracker follows; deployment is C++ with TensorRT.
- MotionBricks is a generative kinematic model, not a controller: it produces stylized reference motion (dance, crawling, stealth, etc.) in real time; in this demo it places the robot directly in each generated pose with no physics step, so it's animation, not simulated control.
- Weights ship under the NVIDIA Open Model License (code is Apache-2.0) — relevant for industrial use; the planner's training code hasn't been released.

**How to run it:**
```bash
just up groot            # standalone demo image
just groot-lfs           # one-time: pull the sim2mujoco LFS assets
just groot-sim           # standalone balance + walk policies (wasd/qe)

just up groot-wbc        # full control-loop image (NVIDIA's prebuilt nvgear/gr00t_wbc)
just groot-wbc-sim       # terminal 1: sim as its own process
just groot-wbc           # terminal 2: control loop (] activate, 9 release, wasd/qe)

just groot-motionbricks  # keyboard-driven generative motion demo
```

**Strengths and limitations observed:**
- Runs zero-shot once the Git LFS assets are pulled; no changes to the upstream repo needed beyond path/glue fixes kept in `docker/groot/`.
- With the sim run as its own process, the full control loop reached ~47 Hz (close to its target) and the walk looked noticeably smoother than holosoma's on this hardware; running the sim in-process instead dropped it to ~5 Hz.
- MotionBricks was the best-looking demo tried, but it's animation (no physics), not evidence of control quality.
- Setup friction is higher than the other two axis winners: Git LFS pointer files throughout the repo, a wrong ONNX policy filename in the standalone demo's config (worked around in `docker/groot/`), a hardcoded `cuda:0` in that same demo, and a 31 GB prebuilt image running as root for the full stack.
- TODO: GEAR-SONIC — the most capable component (full-body motion tracking, not just legs) — was not tried; its feasibility on this hardware is unmeasured, not just assumed heavy.

### Model-based: 

#### wb_humanoid_mpc

**What it is:** real-time nonlinear whole-body MPC for the G1 by Manuel Galliker (ex-ETH), built on OCS2, Pinocchio, HPIPM and ROS 2 Jazzy.

**How it works:**
- Each control cycle solves an optimal-control problem over a future horizon: minimize a cost (track commanded base velocity/height, stay smooth) subject to the robot's dynamics and constraints (contact friction, kinematics, stance foot stationary during support).
- A gait schedule fixes when each foot is in contact; the optimizer chooses contact forces, foot placement and body trajectory to satisfy it.
- Two formulations ship side by side: *centroidal* (center-of-mass linear/angular momentum plus full kinematics, lighter) and *whole-body dynamics* (full joint-space dynamics with contact forces and optional torques, heavier and more coordinated, based on [Galliker et al., 2022](http://ames.caltech.edu/galliker2022bipedal.pdf)).
- OCS2 provides the SQP solver and the MPC/MRT split (MPC solves on one thread, MRT interpolates the solution for the fast control loop); Pinocchio supplies rigid-body dynamics and Jacobians from the G1 URDF; HPIPM is the interior-point QP solver OCS2 calls each SQP iteration.
- Derivatives come from CppAD autodiff codegen, compiled once per container lifetime; the user commands base velocity and height via joystick or GUI.

**How to run it:**
```bash
just up wb-humanoid-mpc
just wb-mpc-build                   # one-time colcon build
just wb-mpc-centroidal-sim          # centroidal MPC, full MuJoCo physics
just wb-mpc-wb-sim                  # whole-body dynamics MPC, full MuJoCo physics
```

**Strengths and limitations observed:**
- The centroidal MPC runs with full MuJoCo physics and holds up: base velocity/height are commandable via joystick or GUI, and of the analytical (non-RL) controllers tested in this evaluation, it produced the smoothest motion.
- Even so, the centroidal sim shows an odd artifact — the robot appears to drift rather than track cleanly. Being the best-performing MPC implementation tested doesn't mean the result is fully convincing.
- The whole-body dynamics MPC thrashes instead of walking, and this reproduces with full MuJoCo physics, not just in the kinematic-only dummy-sim. A real-time thread-priority warning (OCS2 requesting `SCHED_FIFO`, rejected for lack of `CAP_SYS_NICE`) is a plausible but unconfirmed cause — upstream's own README also calls this formulation less mature/documented than the centroidal one.
- First-run autodiff codegen took ~30-40 minutes here, not the README's 5-15 minute estimate (one compiled library per contact/constraint frame) — not a hang, just slow, and paid again on every container recreation.
- Heavy build: the container needs `NVIDIA_VISIBLE_DEVICES=all` set manually (its base image doesn't inherit it), a from-source Pinocchio v3.9.0 rebuild (the apt package resolves to 4.1.0, which breaks this repo's OCS2 fork), and the README's own recommendation of 16 GB RAM for a parallel build.

### Training environment: 

#### holosoma

**What it is:** Amazon FAR's framework for training and deploying RL locomotion/whole-body-tracking policies on humanoids (G1, T1), including motion retargeting from human mocap.

**How it works:**
- Three packages: `holosoma` (training), `holosoma_inference` (deployment), `holosoma_retargeting`.
- Config is composed from modular "managers" — observation, action, command, reward, termination, randomization, curriculum, terrain, reset events — selected per experiment (e.g. `exp:g1-29dof-fast-sac`); new behavior is a config edit, not a new environment.
- Simulator-agnostic training: the same task runs on IsaacGym, IsaacSim or MuJoCo Warp; plain MuJoCo is used only for sim2sim inference, not training.
- Two task families (`locomotion`: velocity-command tracking; `wbt`: whole-body mocap tracking) trained with PPO or FastSAC.
- Trained policies export to ONNX and reuse the same inference pipeline for sim2sim in MuJoCo and for the real robot.
- The retargeting pipeline converts human mocap into G1 motion, preserving object/terrain contact, and feeds the `wbt` training task.

**How to run it:**
```bash
just up holosoma
just holosoma-sim          # terminal 1: mujoco sim (8 lower gantry, 9 release)
just holosoma-policy       # terminal 2: walk ([ start, = walk, wasd/qe)
just holosoma-dance        # terminal 2 alt: whole-body-tracking dance (m plays motion)
```

**Strengths and limitations observed:**
- Runs zero-shot in Docker with no changes to the upstream repo; pretrained ONNX policies (PPO and FastSAC, loco and wbt) load and run on CPU.
- The manager-based config composition looks well suited to iterating on new training setups without touching environment code, and the abstract sim layer (IsaacGym/IsaacSim/MuJoCo Warp) is attractive for training flexibility — this is why it was picked for the training-environment axis over just being another RL demo.
- The practical limit on this hardware is simulation real-time factor, not the policies: upstream's default 2000 Hz physics only reached ~0.3x real time, requiring the rate to be dropped to 500 Hz with `OMP_NUM_THREADS=1` to hold real time headless.
- The whole-body-tracking (dance) demo fell shortly after starting at the default rate; the most likely cause is the real-time mismatch above, but this is unconfirmed — TODO: re-test the dance demo at 500 Hz.
- Actual policy training (the framework's core purpose) needs a strong GPU (IsaacSim/MuJoCo Warp want RTX) and was not exercised in this evaluation, which is zero-shot/inference-only by design; training is out of scope here.


Sources:

- [NVlabs/GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl)
- [manumerous/wb_humanoid_mpc](https://github.com/manumerous/wb_humanoid_mpc)
- [amazon-far/holosoma](https://github.com/amazon-far/holosoma)
- [Galliker et al., Bipedal Locomotion with Nonlinear MPC](http://ames.caltech.edu/galliker2022bipedal.pdf)
- [OCS2](https://github.com/leggedrobotics/ocs2)
- [Pinocchio](https://github.com/stack-of-tasks/pinocchio)
- [HPIPM](https://github.com/giaf/hpipm)