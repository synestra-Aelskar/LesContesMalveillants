"""Conversion des trois calques ImageGen en BLP2/DXT5, alpha conserve."""
import io
import struct
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Outils/sources/lanterne"
DEST = ROOT / "LesContesMalveillants/ressources/lanterne"

def convertir(nom, size):
    source = Image.open(SOURCES / (nom + ".png")).convert("RGBA")
    image = source.resize(size, Image.Resampling.LANCZOS)
    data = io.BytesIO()
    image.save(data, format="DDS", pixel_format="DXT5")
    pixels = data.getvalue()[128:]
    assert len(pixels) == size[0] * size[1]
    header = (b"BLP2" + struct.pack("<I4B2I", 1, 2, 8, 7, 0, *size)
              + struct.pack("<16I", 1172, *([0] * 15))
              + struct.pack("<16I", len(pixels), *([0] * 15)))
    destination = DEST / (nom + ".blp")
    destination.write_bytes(header + bytes(1024) + pixels)
    with Image.open(destination) as controle:
        controle.load()
        assert controle.size == size
        assert controle.getchannel("A").getextrema()[0] == 0
    print(nom, size, "alpha verifie")

if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    for nom, size in {"corps": (1024, 2048), "crochet": (1024, 2048), "cristal": (256, 1024), "levier": (128, 512)}.items():
        convertir(nom, size)
