holosoma_models := "src/holosoma_inference/holosoma_inference/models/loco/g1_29dof"
holosoma_wbt_models := "src/holosoma_inference/holosoma_inference/models/wbt"

build target="all":
    ./docker/scripts/build.sh {{target}}

up name="holosoma":
    ./docker/scripts/run.sh {{name}}

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

g1_ros_env := "source /opt/ros/noetic/setup.bash && source /home/forest_ws/setup.bash"

# one-time (or after code changes): build the mounted walking-demo packages
g1-loco-build:
    docker exec -it g1-locomotion bash -c '{{g1_ros_env}} && cd /home/forest_ws/src/g1_locomotion && make all'

# mpc + wbid walk demo: mujoco sim, mpc/wbid node, robot_state_publisher, rviz
g1-loco-sim:
    docker exec -it g1-locomotion bash -c '{{g1_ros_env}} && roslaunch g1_mujoco_sim mpc_wbid_simulation.launch'

# optional: plotjuggler dashboard of mpc/qp values (load g1_mujoco_sim/config/MPC_QP_layout)
g1-loco-plots:
    docker exec -it g1-locomotion bash -c '{{g1_ros_env}} && rosrun plotjuggler plotjuggler'

# one-time (or after code changes): colcon build (32gb ram host -> 4 parallel jobs, see repo readme)
wb-mpc-build jobs="4":
    docker exec -it wb-humanoid-mpc bash -c 'make build-all PARALLEL_JOBS={{jobs}}'

# centroidal mpc, dummy sim (no physics, just kinematics playback); rviz + base velocity gui
wb-mpc-centroidal-dummy:
    docker exec -it wb-humanoid-mpc bash -c 'make launch-g1-dummy-sim'

# centroidal mpc, full mujoco physics sim
wb-mpc-centroidal-sim:
    docker exec -it wb-humanoid-mpc bash -c 'make launch-g1-sim'

# whole-body dynamics mpc, dummy sim
wb-mpc-wb-dummy:
    docker exec -it wb-humanoid-mpc bash -c 'make launch-wb-g1-dummy-sim'

# whole-body dynamics mpc, full mujoco physics sim
wb-mpc-wb-sim:
    docker exec -it wb-humanoid-mpc bash -c 'make launch-wb-g1-sim'

# one-time (or after code changes): cmake configure + build (plain cmake, no ros/colcon here)
labrob-build:
    docker exec -it labrob bash -c 'mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)'

# offline footstep planning + is-mpc + whole-body qp walk demo, mujoco sim
# (readme says `./main`, actual build target/binary is `main_sim`; must run from build/, paths
# to the robot model are relative to it)
labrob-sim:
    docker exec -it -w /workspace/labrob_mujoco_environment/build labrob ./main_sim --sim

g1control_venv := "/opt/venvs/unitree-g1-control/bin/python"

# regenerate web/model + gains.json from models/g1_walk.xml; NOT required to run the demo
# (web/model/assets + gains.json are already committed), and currently broken here: it needs
# third_party/mujoco_menagerie/unitree_g1/assets, which isn't vendored in this repo/submodule
g1-control-export:
    docker exec -it unitree-g1-control {{g1control_venv}} scripts/export_web_model.py

# serve the web app; open http://127.0.0.1:8765/ on the host (container runs --network host)
g1-control-serve port="8765":
    docker exec -it unitree-g1-control {{g1control_venv}} scripts/serve_web.py {{port}}

# headless regression harness: same wasm + controller.js as the browser, no display needed
# (--ctrl zmp|mpc, --steps N, --len L, --push F,dur,t0, see scripts/sim_node.mjs for all flags)
g1-control-check *args="":
    docker exec -it unitree-g1-control node scripts/sim_node.mjs {{args}}

romoco_ros_env := "source /opt/ros/humble/setup.bash"

# one-time: build the biped-sim image (colcon workspace is built later, inside the container);
# not wired into docker/scripts/build.sh since, like g1-locomotion/wb-humanoid-mpc, this uses its
# own upstream Dockerfile (osrf/ros:humble-desktop-full base), not humanoid-base
romoco-image:
    cd externals/RoMoCo && ./docker/build.sh

# one-time (or after code changes): colcon build
romoco-build jobs="4":
    docker exec -it romoco bash -c '{{romoco_ros_env}} && colcon build --symlink-install --parallel-workers {{jobs}} --cmake-args -DCMAKE_BUILD_TYPE=Release'

# reduced-order planner + whole-body tsc-qp walk demo, mujoco sim; screen_radio gui to send
# commands (e.g. stand -> walk); config in src/g1_stack/config_18dof or config_29dof
romoco-sim:
    docker exec -it romoco bash -c '{{romoco_ros_env}} && source install/setup.bash && ros2 launch g1_stack g1mujoco.launch.py'

# same demo, sim and controller stepped in lockstep (useful if the host cannot keep real time)
romoco-sim-sync:
    docker exec -it romoco bash -c '{{romoco_ros_env}} && source install/setup.bash && ros2 launch g1_stack g1mujocosync.launch.py'
