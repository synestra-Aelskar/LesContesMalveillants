"""Convertit les sources ImageGen en textures TGA pour le menu radial."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / 'sources.json').read_text(encoding='utf-8'))
preview = Image.new('RGB', (660, 150 * ((len(manifest['icons']) + 4) // 5)), '#100f14')
draw = ImageDraw.Draw(preview)
for index, item in enumerate(manifest['icons']):
    source = Image.open(ROOT / 'sources' / (item['id'] + '.png')).convert('RGB')
    # Une marge reservee au masque circulaire conserve les pointes des armes.
    icon = Image.new('RGB', (64, 64), '#100f14')
    icon.paste(source.resize((48, 48), Image.Resampling.LANCZOS), (8, 8))
    # Grille pixel conservee dans la texture finale, dimensions puissance de deux.
    icon.resize((128, 128), Image.Resampling.NEAREST).save(ROOT / (item['id'] + '.tga'))
    x, y = (index % 5) * 132, (index // 5) * 150
    preview.paste(icon.resize((128, 128), Image.Resampling.NEAREST), (x, y))
    draw.text((x + 3, y + 130), item['label'], fill='#d1b57d')
preview.save(ROOT / 'apercu.png')
print(f"{len(manifest['icons'])} textures TGA et apercu generes.")
