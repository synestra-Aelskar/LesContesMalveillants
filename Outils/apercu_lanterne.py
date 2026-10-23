"""Rendu de controle du placement UI, sans modifier les sources graphiques."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Outils/sources/lanterne"
W, H = 210, round(210 * 1438 / 1094)
BX, BY = 220, 40
CX, CY = BX + 0.321 * 520, BY + 0.563 * 260
X, Y = round(CX - .872 * W), round(CY - .14 * H)

def source(nom):
    return Image.open(ART / (nom + ".png")).convert("RGBA")

def region(image, box):
    return image.crop(tuple(round(v * (image.width if i % 2 == 0 else image.height)) for i, v in enumerate(box)))

def rendre(etat):
    image = Image.new("RGBA", (800, 610), (29, 38, 39, 255))
    belt = Image.open(ROOT / "LesContesMalveillants/ressources/ceinture/ceinture.blp").convert("RGBA").resize((520, 260))
    image.alpha_composite(belt, (BX, BY))
    body = source("corps").resize((W, H), Image.Resampling.LANCZOS)
    split, bas = round(.735 * W), round(.30 * H)
    image.alpha_composite(body.crop((0, 0, split, H)), (X, Y))
    image.alpha_composite(body.crop((split, bas, W, H)), (X + split, Y + bas))
    crochet = source("crochet").resize((W, H), Image.Resampling.LANCZOS)
    image.alpha_composite(crochet.crop((split, 0, W, bas)), (X + split, Y))
    if etat != "absent":
        crystal = region(source("cristal"), (.34, .06, .67, .93)).resize((round(W * .13), round(H * .285)))
        if etat == "vide":
            alpha = crystal.getchannel("A")
            crystal = crystal.convert("L").point(lambda p: round(p * .23)).convert("RGBA")
            crystal.putalpha(alpha)
        image.alpha_composite(crystal, (round(X + W * .385 - crystal.width / 2), round(Y + H * .49 - crystal.height / 2)))
    for box in ((.297, .33, .324, .655), (.474, .33, .509, .655)):
        pixels = (round(box[0] * W), round(box[1] * H), round(box[2] * W), round(box[3] * H))
        image.alpha_composite(body.crop(pixels), (X + pixels[0], Y + pixels[1]))
    d = ImageDraw.Draw(image)
    for x, y, w, h, n, value in ((.200,.746,.319,.023,60,35),(.164,.809,.115,.022,24,12),(.437,.809,.118,.022,6,2)):
        left, top, width, height = X + x*W, Y + y*H, w*W, h*H
        if etat == "plein": d.rectangle((left,top,left+width*value/n,top+height),fill=(8,209,102,255))
        for i in range(1,n+1):
            tx = left+(i-.5)*width/n
            d.line((tx,top,tx,top+height*(.7 if i%5==0 else .4)),fill=(199,222,168,255))
    plate = region(source("corps"),(.326,.79,.394,.875)).resize((24,42))
    image.alpha_composite(plate,(round(X+.36*W-12),round(Y+.85*H-21)))
    lever = region(source("levier"),(.32,.07,.68,.93)).resize((12,24))
    if etat != "plein": lever = lever.rotate(180)
    image.alpha_composite(lever,(round(X+.36*W-6),round(Y+.85*H+(-8 if etat=="plein" else 8)-12)))
    ringbox = (round(.321*520-18),round(.563*260-18),round(.321*520+18),round(.563*260+18))
    image.alpha_composite(belt.crop(ringbox),(round(CX-18),round(CY-18)))
    d.text((25,575), {"plein":"Cristal charge / allumee", "vide":"Cristal epuise / eteinte", "absent":"Aucun cristal"}[etat],fill=(242,217,160))
    path = ROOT / "Banc/apercus" / ("lanterne-" + etat + ".png")
    path.parent.mkdir(exist_ok=True)
    image.save(path)
    print(path)

if __name__ == "__main__":
    for etat in ("plein", "vide", "absent"): rendre(etat)
