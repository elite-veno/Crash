"""Road wheels, idler, sprocket. PLACEHOLDER — the running gear builder replaces this. See SPEC.md."""
from lib import *

WHEEL_X = [1.95, 1.07, 0.10, -0.80, -1.68]


def build():
    src = lathe("road_wheel_src", [(0, -0.19), (0.415, -0.19), (0.415, 0.19), (0, 0.19)], "running_gear", "rubber",
                64, (WHEEL_X[0], -1.225, 0.475), (math.pi / 2, 0, 0))
    for side in (-1, 1):
        for i, x in enumerate(WHEEL_X):
            if side == -1 and i == 0:
                continue
            instance(src, f"road_wheel_{side}_{i}", "running_gear", (x, side * 1.225, 0.475), (math.pi / 2, 0, 0))
