"""Crop and enlarge a region of the reference photo (or any image) to study details.

    python3 crop.py 180 20 330 140 --scale 4 --out /tmp/turret.png      # x0 y0 x1 y1 in photo pixels (474x266)
"""
import argparse
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

ap = argparse.ArgumentParser()
ap.add_argument("box", type=int, nargs=4)
ap.add_argument("--scale", type=float, default=4)
ap.add_argument("--img", default=os.path.join(HERE, "reference", "photo.png"))
ap.add_argument("--out", required=True)
a = ap.parse_args()
im = Image.open(a.img).convert("RGB").crop(tuple(a.box))
im = im.resize((int(im.width * a.scale), int(im.height * a.scale)), Image.LANCZOS)
im.save(a.out)
print(a.out)
