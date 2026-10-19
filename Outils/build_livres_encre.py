"""Atlas typographique Caudex pour projeter l'encre avec le papier anime."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import argparse

repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--font', type=Path, default=repo/'LesContesMalveillants/ressources/bannieres/polices/Caudex-Regular.ttf')
parser.add_argument('--output', type=Path, default=repo/'LesContesMalveillants/ressources/livres')
parser.add_argument('--lua-output', type=Path, default=repo/'LesContesMalveillants/UI/LivresGlyphes.lua')
parser.add_argument('--preview', action='store_true', help='Exporter aussi PNG et metriques JSON pour le controle visuel')
args = parser.parse_args()
ROOT, FONT = args.output, args.font
ROOT.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype(str(FONT), 32)
chars = list(dict.fromkeys(chr(n) for n in list(range(32, 384)) + [0x2013,0x2014,0x2018,0x2019,0x201c,0x201d,0x2026,0x2022,0x20ac,0x2190,0x2192]))
atlas = Image.new('RGBA', (1024, 1024))
draw = ImageDraw.Draw(atlas)
glyphs = {}
lines = ['-- Genere a partir de Caudex-Regular.ttf (police deja fournie par l addon).', 'local _, LCM = ...', 'LCM.UI.LivresGlyphes = { taille = 32, ascente = %d, hauteur = %d, lettres = {' % (font.getmetrics()[0],sum(font.getmetrics()))]
for index, char in enumerate(chars):
    x, y = (index % 21)*48+5, (index // 21)*48+36
    left,top,right,bottom=font.getbbox(char,anchor='ls')
    draw.text((x,y),char,font=font,fill='white',anchor='ls')
    data=[round(font.getlength(char),4),left-1,top-1,max(1,right-left+2),max(1,bottom-top+2),(x+left-1)/1024,(y+top-1)/1024,(x+right+1)/1024,(y+bottom+1)/1024]
    glyphs[char]=data
    key=''.join('\\%03d'%byte for byte in char.encode('utf-8'))
    lines.append('    ["%s"] = { %s },'%(key,', '.join(str(n) for n in data)))
lines.append('} }')
atlas.save(ROOT/'encre-caudex.tga')
args.lua_output.write_text('\n'.join(lines)+'\n',encoding='utf-8')
if args.preview:
    atlas.save(ROOT/'encre-caudex.png')
    (ROOT/'glyphs.json').write_text(json.dumps({'taille':32,'ascente':font.getmetrics()[0],'hauteur':sum(font.getmetrics()),'lettres':glyphs},ensure_ascii=False),encoding='utf-8')
print(len(glyphs), 'glyphes, atlas', atlas.size)
