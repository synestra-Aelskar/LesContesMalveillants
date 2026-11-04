"""Projection geometrique du cuir existant, sans changement de dessin.

Construit les textures du second niveau avec un rayon concentrique plus grand,
une epaisseur identique et la meme longueur d'arc par entree. Pillow requis.
Les constantes physiques correspondent a UI/Radial.lua.
"""
from pathlib import Path
from math import atan2, hypot, sin, cos
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / 'LesContesMalveillants/ressources/radial'
BASE, OUTPUT, PIXELS = 436, 640, 1024
INNER, OUTER = BASE * 309 / 1024, BASE * 470 / 1024
RADIUS = (INNER + OUTER) / 2
OFFSET = OUTER - INNER + 16
RATIO = (RADIUS + OFFSET) / RADIUS


def project(x, y):
    dx, dy = (x - PIXELS / 2) * OUTPUT / PIXELS, (y - PIXELS / 2) * OUTPUT / PIXELS
    radius = (hypot(dx, dy) - OFFSET) * PIXELS / BASE
    angle = atan2(dx, -dy) * RATIO
    return PIXELS / 2 + sin(angle) * radius, PIXELS / 2 - cos(angle) * radius


def build():
    mesh = []
    for y in range(0, PIXELS, 8):
        for x in range(0, PIXELS, 8):
            dx, dy = (x + 4 - 512) * OUTPUT / PIXELS, (y + 4 - 512) * OUTPUT / PIXELS
            if not INNER + OFFSET - 12 < hypot(dx, dy) < OUTER + OFFSET + 12:
                continue
            if abs(atan2(dx, -dy)) > 1.3:
                continue
            quad = sum((project(a, b) for a, b in ((x, y), (x, y+8), (x+8, y+8), (x+8, y))), ())
            mesh.append(((x, y, x+8, y+8), quad))
    for count in range(1, 10):
        source = Image.open(ART / f'grimoire-fan-{count}.tga').convert('RGBA')
        assert source.size == (PIXELS, PIXELS)
        result = source.transform((PIXELS, PIXELS), Image.Transform.MESH, mesh, Image.Resampling.BICUBIC)
        result.save(ART / f'grimoire-subfan-{count}.tga', compression=None)


if __name__ == '__main__':
    build()
