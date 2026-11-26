"""Extract the standard 2D material panels embedded in a generated GLB."""
import argparse
import io
from pathlib import Path
from PIL import Image
from tailor_ai.garment3d.garment_photo_projection import decode_glb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    doc, blob = decode_glb(args.glb.read_bytes())
    view = doc['bufferViews'][doc['images'][0]['bufferView']]
    start = view.get('byteOffset', 0)
    image = Image.open(io.BytesIO(blob[start:start+view['byteLength']])).convert('RGB')
    if image.size != (2048, 2048): raise SystemExit('Not a standard 2048-pixel material atlas.')
    args.output.mkdir(parents=True, exist_ok=True)
    for name, box in [('front', (0, 0, 1024, 2048)), ('back', (1024, 0, 2048, 2048))]:
        path = args.output/(name+'-panels.png')
        image.crop(box).save(path); print(path)


if __name__ == '__main__': main()
