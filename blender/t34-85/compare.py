"""Put the reference photo next to a render (and a 50% overlay) for visual comparison.

    python3 compare.py renders/photo.png --out renders/compare.png
"""
import argparse
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("render")
    ap.add_argument("--out", default=None)
    ap.add_argument("--height", type=int, default=400)
    args = ap.parse_args()
    ref = Image.open(os.path.join(HERE, "reference", "photo.png")).convert("RGB")
    ren = Image.open(args.render).convert("RGB")
    h = args.height
    ref = ref.resize((int(ref.width * h / ref.height), h), Image.LANCZOS)
    ren = ren.resize((int(ren.width * h / ren.height), h), Image.LANCZOS)
    over = Image.blend(ref, ren.resize(ref.size, Image.LANCZOS), 0.5)
    sheet = Image.new("RGB", (ref.width + ren.width + over.width + 20, h), (255, 255, 255))
    sheet.paste(ref, (0, 0))
    sheet.paste(ren, (ref.width + 10, 0))
    sheet.paste(over, (ref.width + ren.width + 20, 0))
    out = args.out or os.path.splitext(args.render)[0] + "_compare.png"
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
