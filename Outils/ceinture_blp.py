"""Convertit la source transparente de la ceinture en BLP2/DXT5 pour WoW."""

import io
from pathlib import Path
import struct

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Outils/sources/ceinture/ceinture.png"
DEST = ROOT / "LesContesMalveillants/ressources/ceinture/ceinture.blp"
SIZE = (1024, 512)


def main():
    image = Image.open(SOURCE).convert("RGBA")
    image.thumbnail((SIZE[0] - 16, SIZE[1] - 16), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", SIZE)
    canvas.paste(image, ((SIZE[0] - image.width) // 2, (SIZE[1] - image.height) // 2))
    dds = io.BytesIO()
    canvas.save(dds, format="DDS", pixel_format="DXT5")
    pixels = dds.getvalue()[128:]
    assert len(pixels) == SIZE[0] * SIZE[1]
    header = (b"BLP2" + struct.pack("<I4B2I", 1, 2, 8, 7, 0, *SIZE)
              + struct.pack("<16I", 148 + 1024, *([0] * 15))
              + struct.pack("<16I", len(pixels), *([0] * 15)))
    DEST.write_bytes(header + bytes(1024) + pixels)
    with Image.open(DEST) as checked:
        checked.load()
        assert checked.size == SIZE and checked.getchannel("A").getextrema()[0] == 0


if __name__ == "__main__":
    main()
