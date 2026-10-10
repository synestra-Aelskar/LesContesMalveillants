"""L'empan angulaire et le rayon de chaque bandeau.

Si l'empan croit d'un pas constant, le bandeau n'est pas une image par
« nombre de branches » mais un arc de N fois le meme secteur : une neuvieme
longueur est alors la suite de la meme serie, pas un dessin a inventer.
"""
import math
import os

from PIL import Image

BASE = (r"F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns"
        r"\LesContesMalveillants\ressources\radial")


def mesurer(nom):
    im = Image.open(os.path.join(BASE, nom)).convert("RGBA")
    w, h = im.size
    px = im.load()
    cx, cy = w / 2.0, h / 2.0

    # Le rayon interieur et exterieur : on balaie un rayon vertical vers le haut.
    rint, rext = None, None
    for rr in range(0, int(w / 2)):
        x, y = int(cx), int(cy - rr)
        if 0 <= y < h and px[x, y][3] > 16:
            if rint is None:
                rint = rr
            rext = rr
    if rint is None:
        return None

    # L'empan, mesure au milieu de l'anneau.
    rmid = (rint + rext) / 2.0
    present = []
    for deg in range(0, 7200):
        a = math.radians(deg / 20.0) - math.pi / 2
        x, y = int(cx + rmid * math.cos(a)), int(cy + rmid * math.sin(a))
        if 0 <= x < w and 0 <= y < h and px[x, y][3] > 16:
            present.append(deg / 20.0)
    empan = (len(present) / 20.0) if present else 0.0
    debut, fin = (present[0], present[-1]) if present else (0, 0)
    return rint, rext, empan, debut, fin


print("%-6s %7s %7s %9s %8s %8s" % ("fan", "r int", "r ext", "empan", "debut", "fin"))
precedent = None
for n in range(1, 9):
    m = mesurer("grimoire-fan-%d.tga" % n)
    if not m:
        print("%-6d introuvable" % n)
        continue
    rint, rext, empan, debut, fin = m
    pas = "" if precedent is None else ("  (+%.1f)" % (empan - precedent))
    print("%-6d %7d %7d %8.1f°%s %7.1f° %7.1f°" % (n, rint, rext, empan, pas, debut, fin))
    precedent = empan
