"""Allonger un bandeau de l'eventail d'une branche.

Les huit bandeaux sont le MEME objet a huit longueurs : meme rayon interieur
(~308) et exterieur (~470), et un empan qui croit d'un pas constant de ~20,6
degres par branche. Une neuvieme longueur n'est donc pas un dessin a inventer,
c'est la suite de la serie.

On la fabrique par un « neuf-tranches » ANGULAIRE : les deux embouts (les
ornements d'angle dores) restent au 1:1, et seule la partie centrale — du cuir
et deux filets d'or, uniformes — s'etire. Rien n'est repeint : ce sont les
vrais pixels du bandeau de huit.

La methode se verifie avant de s'en servir : on refabrique le bandeau de HUIT
a partir de celui de SEPT, et on le compare au vrai.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

BASE = (r"F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns"
        r"\LesContesMalveillants\ressources\radial")

# Mesure : l'empan croit de ce pas a chaque branche (voir mesurer_fan.py).
PAS = math.radians(20.6)
# Ce qu'on garde intact a chaque bout : l'ornement d'angle tient dans 18°, et
# le bandeau d'UNE branche fait 32,5° a lui seul (deux embouts colles).
EMBOUT = math.radians(18.0)


def charger(n):
    chemin = os.path.join(BASE, "grimoire-fan-%d.tga" % n)
    return np.asarray(Image.open(chemin).convert("RGBA"), dtype=np.float32)


def empan(img):
    """L'empan angulaire du bandeau, centre sur le haut. Rend la demi-largeur."""
    h, w, _ = img.shape
    cy, cx = h / 2.0, w / 2.0
    ys, xs = np.nonzero(img[:, :, 3] > 8)
    if len(xs) == 0:
        raise SystemExit("bandeau vide")
    # Angle compte depuis le HAUT, positif vers la droite, dans [-pi, pi].
    a = np.arctan2(xs - cx, cy - ys)
    return float(np.max(np.abs(a)))


def allonger(img, demiSource, demiCible):
    """Remappe l'angle : embouts au 1:1, milieu etire. Echantillonnage bilineaire."""
    h, w, _ = img.shape
    cy, cx = h / 2.0, w / 2.0

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = xx - cx, cy - yy
    rr = np.hypot(dx, dy)
    aa = np.arctan2(dx, dy)          # 0 = vers le haut, positif a droite

    # Le remappage est symetrique : on travaille sur |angle| et on remet le signe.
    signe = np.sign(aa)
    absa = np.abs(aa)

    milieuSource = demiSource - EMBOUT
    milieuCible = demiCible - EMBOUT
    if milieuSource <= 0 or milieuCible <= 0:
        raise SystemExit("embout trop large pour ce bandeau")
    facteur = milieuSource / milieuCible   # cible -> source

    source = np.where(absa <= milieuCible, absa * facteur, absa - (demiCible - demiSource))
    source = source * signe

    # Retour en coordonnees image.
    sx = cx + rr * np.sin(source)
    sy = cy - rr * np.cos(source)

    # Bilineaire, avec bord transparent hors cadre.
    x0 = np.floor(sx).astype(np.int32)
    y0 = np.floor(sy).astype(np.int32)
    fx = (sx - x0)[..., None]
    fy = (sy - y0)[..., None]

    def lire(ix, iy):
        bon = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
        out = np.zeros((h, w, 4), dtype=np.float32)
        out[bon] = img[np.clip(iy, 0, h - 1)[bon], np.clip(ix, 0, w - 1)[bon]]
        return out

    c00, c10 = lire(x0, y0), lire(x0 + 1, y0)
    c01, c11 = lire(x0, y0 + 1), lire(x0 + 1, y0 + 1)
    haut = c00 * (1 - fx) + c10 * fx
    bas = c01 * (1 - fx) + c11 * fx
    return haut * (1 - fy) + bas * fy


def ecrire(tableau, chemin):
    im = Image.fromarray(np.clip(tableau + 0.5, 0, 255).astype(np.uint8), "RGBA")
    im.save(chemin)
    return im


if __name__ == "__main__":
    # ----- la verification : huit, refabrique a partir de sept --------------
    sept, huit = charger(7), charger(8)
    d7, d8 = empan(sept), empan(huit)
    print("demi-empan mesure : fan-7 %.2f°  fan-8 %.2f°  (ecart %.2f°)"
          % (math.degrees(d7), math.degrees(d8), math.degrees(d8 - d7)))

    refait = allonger(sept, d7, d8)
    ecrire(refait, "fan-8-refait.png")

    # L'ecart, la ou il y a quelque chose a comparer.
    masque = (huit[:, :, 3] > 8) | (refait[:, :, 3] > 8)
    ecart = np.abs(refait[masque] - huit[masque])
    print("fan-8 refait vs vrai : ecart moyen %.2f / 255, median %.2f, 99e centile %.2f"
          % (ecart.mean(), np.median(ecart), np.percentile(ecart, 99)))
    couv = ((huit[:, :, 3] > 8) & (refait[:, :, 3] > 8)).sum()
    print("pixels couverts par les deux : %d sur %d (%.1f %%)"
          % (couv, masque.sum(), 100.0 * couv / masque.sum()))

    # ----- la neuvieme longueur --------------------------------------------
    d9 = d8 + PAS / 2.0     # l'empan TOTAL croit de PAS, la demi-largeur de PAS/2
    neuf = allonger(huit, d8, d9)
    sortie = os.path.join(BASE, "grimoire-fan-9.tga")
    if "--ecrire" in sys.argv:
        im = Image.fromarray(np.clip(neuf + 0.5, 0, 255).astype(np.uint8), "RGBA")
        im.save(sortie)
        print("ecrit :", sortie, "— empan total %.1f°" % math.degrees(2 * d9))
    else:
        ecrire(neuf, "fan-9-apercu.png")
        print("apercu seulement (passer --ecrire pour poser le .tga) — "
              "empan total %.1f°" % math.degrees(2 * d9))
