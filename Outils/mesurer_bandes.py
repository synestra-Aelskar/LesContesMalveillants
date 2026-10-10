"""Ou chaque bande du cadre devient-elle OPAQUE ?

Le fond d'une fenetre s'arrete a son rectangle ; les bandes du cadre, elles,
debordent au-dehors. Entre les deux, il n'y a rien : sur un ciel clair, la
bordure a l'air faite de lumiere.

Le bord du HAUT a deja ete rattrape, avec une fraction mesuree a la main
(`railOpaque = 34/110`). On mesure ici la meme chose pour les trois autres
bords, et on verifie au passage celle du haut.

Une bande est une tranche de l'atlas etiree le long d'un bord. Sa section —
les 70 colonnes d'une bande laterale, les 110 ou 160 lignes d'une bande
horizontale — porte le degrade qui va du vide (dehors) a l'opaque (dedans).
On cherche a quelle fraction de cette section l'alpha devient franc.
"""
import os

import numpy as np
from PIL import Image

BASE = (r"F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns"
        r"\LesContesMalveillants\ressources\aelrazkah")

# Les bandes, telles que UI/Skin.lua les declare : rect source (x, y, w, h),
# et le sens dans lequel la section se lit.
#   « colonnes » : la section est horizontale (bande verticale, cote gauche ou
#                  droit) — on lit l'alpha colonne par colonne.
#   « lignes »   : la section est verticale (bande horizontale, haut ou bas).
VARIANTES = {
    "frame-panel.tga": {
        "tw": 1024, "th": 1024,
        "bandes": [
            ("haut  (rail)",       610, 340, 12, 160, "lignes",   "dehors=haut"),
            ("haut  (rail bis)",   632, 340, 12, 160, "lignes",   "dehors=haut"),
            ("bas   (rail)",       654, 340, 12, 110, "lignes",   "dehors=bas"),
            ("cote  gauche",       668, 340, 70,  12, "colonnes", "dehors=gauche"),
            ("cote  droit",        668, 356, 70,  12, "colonnes", "dehors=droite"),
        ],
    },
}

SEUIL = 0.60   # « franchement opaque » : au-dela, le noir derriere ne se voit plus


def mesurer(nom, fichier, x, y, w, h, sens, bord):
    im = Image.open(os.path.join(BASE, fichier)).convert("RGBA")
    # L'atlas livre est une reduction de la source : les coordonnees du gabarit
    # sont en unites de la SOURCE, il faut les ramener a l'image.
    info = VARIANTES[fichier]
    ex = im.size[0] / info["tw"]
    ey = im.size[1] / info["th"]
    bloc = np.asarray(im, dtype=np.float32)[
        int(y * ey):int((y + h) * ey), int(x * ex):int((x + w) * ex), 3] / 255.0
    if bloc.size == 0:
        print("  %-18s : bloc vide" % nom)
        return

    if sens == "colonnes":
        profil = bloc.mean(axis=0)          # une valeur par colonne
    else:
        profil = bloc.mean(axis=1)          # une valeur par ligne

    n = len(profil)
    # Le « dehors » est au debut du profil pour le haut, la gauche ; a la fin
    # pour le bas et la droite. On lit toujours depuis le dehors.
    depuis_la_fin = bord in ("dehors=bas", "dehors=droite")
    lecture = profil[::-1] if depuis_la_fin else profil

    premier = None
    for i, a in enumerate(lecture):
        if a >= SEUIL:
            premier = i
            break
    if premier is None:
        print("  %-18s : jamais opaque (max %.2f sur %d)" % (nom, lecture.max(), n))
        return
    print("  %-18s : opaque a partir de %d/%d  = %.3f   (max %.2f)"
          % (nom, premier, n, premier / n, lecture.max()))


for fichier, info in VARIANTES.items():
    im = Image.open(os.path.join(BASE, fichier))
    print("--- %s  (%dx%d, gabarit %dx%d)" % (fichier, im.size[0], im.size[1],
                                              info["tw"], info["th"]))
    for nom, x, y, w, h, sens, bord in info["bandes"]:
        mesurer(nom, fichier, x, y, w, h, sens, bord)
