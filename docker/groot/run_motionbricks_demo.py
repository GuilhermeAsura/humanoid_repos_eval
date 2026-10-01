import runpy

import torch

_torch_load = torch.load


def _load_trusted(*args, weights_only=False, **kwargs):
    # motionbricks' own checkpoint (pulled via this repo's Git LFS, from NVIDIA's repo)
    # isn't a plain tensor state_dict; PyTorch 2.6 flipped torch.load's weights_only
    # default to True and the restricted unpickler rejects it. Source is trusted, so
    # restore the pre-2.6 default here instead of patching the vendored
    # motion_backbone/models/pose_model.py.
    return _torch_load(*args, weights_only=weights_only, **kwargs)


torch.load = _load_trusted

if __name__ == "__main__":
    runpy.run_path("scripts/interactive_demo_g1.py", run_name="__main__")
