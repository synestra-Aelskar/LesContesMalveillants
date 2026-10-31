"""Planche de controle des BLP et polices livres (pas une capture WoW)."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Banc'))
import lcm_bench

lua = lcm_bench.charger(str(ROOT / 'Banc/scenarios/lcm_test_affichages.lua'))
assert lua is not None
catalogue = lua.globals().LCM
dest = ROOT / 'Banc/apercus/affichages'
dest.mkdir(parents=True, exist_ok=True)


def chemin(wow):
    return ROOT / wow.replace('Interface\\AddOns\\', '').replace('\\', '/')


def texte(draw, text, font, x, y, width, color):
    for paragraphe in text.split('\n'):
        ligne = ''
        for mot in paragraphe.split():
            candidat = (ligne + ' ' + mot).strip()
            if ligne and draw.textlength(candidat, font=font) > width:
                draw.text((x, y), ligne, font=font, fill=color)
                y += font.size + 4
                ligne = mot
            else:
                ligne = candidat
        draw.text((x, y), ligne, font=font, fill=color)
        y += font.size + 8
    return y


sheet = Image.new('RGB', (1080, 1080), '#171c26')
draw = ImageDraw.Draw(sheet)
label = ImageFont.truetype(str(chemin(catalogue.AffichagesPolices[1].chemin)), 18)
choix = ['classique', 'medievale', 'calligraphie', 'numerique', 'gothique', 'machine']
for i in range(1, 7):
    theme = catalogue.AffichagesThemes[i]
    police = catalogue.Affichages.Police(choix[i - 1])
    x, y = ((i - 1) % 3) * 360 + 10, ((i - 1) // 3) * 540 + 40
    fond = Image.open(chemin(theme.texture)).convert('RGBA').resize((340, 480))
    sheet.paste(fond, (x, y), fond)
    draw.text((x, y - 28), theme.label + ' / ' + police.id, font=label, fill='#e6dccb')
    color = tuple(round(theme.encre[j] * 255) for j in range(1, 4))
    title = ImageFont.truetype(str(chemin(police.chemin)), round(23 * (police.facteur or 1)))
    body = ImageFont.truetype(str(chemin(police.chemin)), round(18 * (police.facteur or 1)))
    texte(draw, 'Avis aux voyageurs', title, x + 28, y + 32, 284, color)
    texte(draw, 'À la tombée du jour, les portes seront fermées.\nRendez-vous à la taverne pour préparer le départ.\nÉquipement, vivres et cartes : chacun est invité à vérifier ses réserves.\n« Que la route vous soit douce. »',
          body, x + 28, y + 100, 284, color)
sheet.save(dest / 'affiches-et-ecritures.png')

sheet = Image.new('RGB', (1440, 720), '#171c26')
draw = ImageDraw.Draw(sheet)
for i in range(1, 7):
    support = catalogue.AffichagesSupports[i]
    x, y = ((i - 1) % 3) * 480, ((i - 1) // 3) * 360 + 30
    sheet.paste(Image.open(chemin(support.texture)).convert('RGB').resize((480, 320)), (x, y))
    draw.text((x + 10, y - 27), support.label, font=label, fill='#e6dccb')
sheet.save(dest / 'panneaux.png')
print('Apercus :', dest)
