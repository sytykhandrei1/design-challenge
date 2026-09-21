#!/usr/bin/env python3
"""Offline authoring only; requires NumPy/Pillow, never runs in the iOS build.

Existing source micro-height signals are sampled in physical millimetres. This
creates new technical maps, without editing/reusing the old card artwork.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-root', type=Path, default=ROOT / 'CardMaterials/v1/shared/micro')
parser.add_argument('--output', type=Path, default=ROOT / 'Plata/PlataPlasticV1/Resources/plata_plastic_v1')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
# A 3x iPhone card spans ~3000 pixels at the viewer's maximum 3x zoom.
SIZE = (3072, 1937)
W, H, T, R = 85.60, 53.98, 0.76, 3.18
PERIMETER = 2 * (W + H - 4 * R) + 2 * np.pi * R
SETTINGS = {
    'matte': ('matte-plastic', .68, .027, .00065),
    'satin': ('brushed-metal', .40, .018, .00032),
    'gloss': ('glossy-plastic', .17, .008, .000055),
}

def sample(tile, size, physical, phase, periodic_x=False):
    w, h = size
    th, tw = tile.shape
    # Edge wraps by an integer number of repeats: no discontinuity at its seam.
    repeats = round(physical[0] / 16) if periodic_x else physical[0] / 16
    x = ((np.arange(w, dtype=np.float32) + .5) / w * repeats + phase[0]) * tw
    y = ((np.arange(h, dtype=np.float32) + .5) / h * physical[1] / 16 + phase[1]) * th
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - ix)[None, :], (y - iy)[:, None]
    a, b = tile[iy[:, None] % th, ix[None, :] % tw], tile[iy[:, None] % th, (ix[None, :] + 1) % tw]
    c, d = tile[(iy[:, None] + 1) % th, ix[None, :] % tw], tile[(iy[:, None] + 1) % th, (ix[None, :] + 1) % tw]
    return ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy).astype(np.float32)

manifest = {'version': 1, 'physical_mm': [W, H, T], 'normal': 'OpenGL tangent space +Y up',
            'technical_png': 'Linear data; R8 roughness, RGB8 normal; no ICC/gAMA; no compression in RealityKit',
            'base_color': 'Uniform sRGB material tint, no baked lighting', 'plastic_metallic': 0,
            'runtime_height': False, 'materials': {}, 'files': {}}
for finish, (source, roughness, variation, amplitude) in SETTINGS.items():
    source_path = args.source_root / source / 'height-signal.npy'
    tile = np.load(source_path, allow_pickle=False)
    manifest['materials'][finish] = {'source': source, 'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
        'roughness': roughness, 'roughness_variation': variation, 'height_amplitude_mm': amplitude, 'period_mm': 16}
    for side, size, physical, phase in [('front', SIZE, (W, H), (0, 0)),
                                       ('back', SIZE, (W, H), (.37, .59)),
                                       ('edge', (4096, 64), (PERIMETER, T), (.17, .31))]:
        signal = sample(tile, size, physical, phase, periodic_x=side == 'edge')
        height = signal * amplitude
        dy, dx = np.gradient(height, physical[1] / size[1], physical[0] / size[0])
        if side == 'edge':
            dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) / (2 * physical[0] / size[0])
        normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
        normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
        images = {'normal_opengl': np.round(np.clip(normal * .5 + .5, 0, 1) * 255).astype(np.uint8),
                  'roughness': np.round(np.clip(roughness + signal * variation, 0, 1) * 255).astype(np.uint8)}
        for kind, pixels in images.items():
            filename = f'{finish}_{side}_{kind}.png'
            path = args.output / filename
            Image.fromarray(pixels).save(path, compress_level=9)
            manifest['files'][filename] = {'size': list(size), 'channels': 'RGB' if pixels.ndim == 3 else 'R',
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    print(f'{finish}: front/back {SIZE}, edge 4096x64', flush=True)
(args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
