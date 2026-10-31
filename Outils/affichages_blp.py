"""Convertit les 12 PNG ImageGen en BLP2/DXT5, puis verifie leur relecture.

python Outils/affichages_blp.py
Les images sont stockees en puissance de deux ; le Lua restitue leur rapport.
"""
import io
import struct
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Outils/sources/affichages'
DEST = ROOT / 'LesContesMalveillants/ressources/affichages'


def convertir(source):
    taille = (1024, 1024)
    image = Image.open(source).convert('RGBA').resize(taille, Image.Resampling.LANCZOS)
    alpha_source = image.getchannel('A').getextrema()
    if source.stem == 'affiche-parchemin':
        assert alpha_source[0] == 0 and alpha_source[1] >= 250, 'Le parchemin doit avoir un exterieur transparent'
        assert image.getpixel((512, 512))[3] >= 250, 'La zone de lecture doit rester opaque'
    dds = io.BytesIO()
    image.save(dds, format='DDS', pixel_format='DXT5')
    pixels = dds.getvalue()[128:]
    assert len(pixels) == taille[0] * taille[1]
    entete = (b'BLP2' + struct.pack('<I4B2I', 1, 2, 8, 7, 0, *taille)
              + struct.pack('<16I', 1172, *([0] * 15))
              + struct.pack('<16I', len(pixels), *([0] * 15)))
    cible = DEST / (source.stem + '.blp')
    cible.write_bytes(entete + bytes(1024) + pixels)
    with Image.open(cible) as relu:
        relu.load()
        assert relu.size == taille and relu.mode == 'RGBA'
        alpha_blp = relu.getchannel('A').getextrema()
        assert all(abs(a - b) <= 4 for a, b in zip(alpha_source, alpha_blp))
        if source.stem == 'affiche-parchemin':
            assert relu.getpixel((0, 0))[3] <= 4
            assert relu.getpixel((1023, 1023))[3] <= 4
            assert relu.getpixel((512, 512))[3] >= 250
    print(cible.name, '1024x1024 DXT5 OK')


if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    sources = sorted(SOURCE.glob('*.png'))
    assert len(sources) == 12, 'Les douze sources sont requises'
    for source in sources:
        convertir(source)
