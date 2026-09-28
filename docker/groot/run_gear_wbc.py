import os
import sys

ROOT = os.environ.get("GROOT_ROOT", "/workspace/GR00T-WholeBodyControl")
SIM_DIR = os.path.join(ROOT, "decoupled_wbc", "sim2mujoco")
sys.path.insert(0, os.path.join(SIM_DIR, "scripts"))

import run_mujoco_gear_wbc as upstream  # noqa: E402

upstream.CONFIG_PATH = os.path.join(SIM_DIR, "resources", "robots", "g1")
_load_config = upstream.GearWbcController.load_config


def load_config(self, config_path):
    config = _load_config(self, config_path)
    # upstream yaml points to ft92/ft109.onnx, which are not shipped; use the released balance/walk policies
    policy_dir = os.path.join(upstream.CONFIG_PATH, "policy")
    config["policy_path"] = os.path.join(policy_dir, "GR00T-WholeBodyControl-Balance.onnx")
    config["walk_policy_path"] = os.path.join(policy_dir, "GR00T-WholeBodyControl-Walk.onnx")
    return config


upstream.GearWbcController.load_config = load_config

if __name__ == "__main__":
    upstream.GearWbcController(upstream.CONFIG_PATH).run()
