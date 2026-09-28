holosoma_models := "src/holosoma_inference/holosoma_inference/models/loco/g1_29dof"
holosoma_wbt_models := "src/holosoma_inference/holosoma_inference/models/wbt"

build target="all":
    ./docker/build.sh {{target}}

up name="holosoma":
    ./docker/run.sh {{name}}

down name="holosoma":
    docker rm -f {{name}}

shell name="holosoma":
    docker exec -it {{name}} bash

gpu name="holosoma":
    docker exec -it {{name}} nvidia-smi

# terminal 1: mujoco sim (keys in viewer: 8 lower gantry, 9 remove it)
# upstream 2000 hz physics runs at ~0.35x real time on this cpu; policies need ~1x
holosoma-sim fps="500":
    docker exec -it -e OMP_NUM_THREADS=1 holosoma /opt/venvs/hsmujoco/bin/python src/holosoma/holosoma/run_sim.py robot:g1-29dof \
        --simulator.config.sim.fps {{fps}}

# terminal 2: policy (] start, = walk, wasd/qe velocity)
holosoma-policy model="fastsac":
    docker exec -it holosoma /opt/venvs/hsinference/bin/python src/holosoma_inference/holosoma_inference/run_policy.py inference:g1-29dof-loco \
        --task.model-path {{holosoma_models}}/{{model}}_g1_29dof.onnx \
        --task.no-use-joystick \
        --task.interface lo

# terminal 2: dance policy (enter stiff mode, ] start, m play motion)
holosoma-dance model="fastsac":
    docker exec -it holosoma /opt/venvs/hsinference/bin/python src/holosoma_inference/holosoma_inference/run_policy.py inference:g1-29dof-wbt \
        --task.model-path {{holosoma_wbt_models}}/{{model}}_g1_29dof_dancing.onnx \
        --task.no-use-joystick \
        --task.use-sim-time \
        --task.rl-rate 50 \
        --task.interface lo

# one-time: fetch the lfs meshes/onnx the mujoco demo needs
groot-lfs:
    docker exec -it groot git lfs pull --include="decoupled_wbc/sim2mujoco/**"

# mujoco sim + balance/walk policies in one process (wasd/qe velocity, z reset cmd)
groot-sim:
    docker exec -it groot /opt/venvs/groot/bin/python /opt/glue/run_gear_wbc.py

groot_wbc_env := "source /root/venv/bin/activate && source /opt/ros/humble/setup.bash && export ROS_LOCALHOST_ONLY=1"

# terminal 1: decoupled_wbc mujoco sim (own process; in-process sim starves the control loop to ~5 hz)
groot-wbc-sim:
    docker exec -it groot-wbc bash -c '{{groot_wbc_env}} && python decoupled_wbc/control/main/teleop/run_sim_loop.py'

# terminal 2: control loop (] activate, 9 release, wasd/qe, z zero, 1/2 height)
groot-wbc:
    docker exec -it groot-wbc bash -c '{{groot_wbc_env}} && python decoupled_wbc/control/main/teleop/run_g1_control_loop.py --simulator None'

# motionbricks interactive demo (kinematic, no physics); wasd move, style keys in the readme
groot-motionbricks:
    docker exec -it -w /workspace/GR00T-WholeBodyControl/motionbricks groot /opt/venvs/motionbricks/bin/python scripts/interactive_demo_g1.py

# pick & place scene with walker/reacher policies (keys in the mujoco window: arrows, ; ' turn, . walk/reach, , grip)
luckyrobots-sim:
    docker exec -it luckyrobots /opt/venvs/luckyrobots/bin/python run.py
