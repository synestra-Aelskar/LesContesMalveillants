# -*- coding: utf-8 -*-
"""Convertit les artworks des personnages en textures lisibles par WoW.

    python Outils/portraits.py [--apercu]

Depose tes images (png, jpg, webp...) dans F:\\WOW EPSILON\\LesContesMalveillants\\Portraits,
nommees d'apres le personnage — « Reika Shira.png », « nytherah.jpg ». L'outil :

  * recadre au format 2:3 (le cadrage suit le HAUT de l'image : sur un portrait,
    ce qui compte est le visage, pas les pieds) ;
  * ecrit un TGA 32 bits non compresse de 256 x 512, l'image occupant les 384
    premiers pixels — le moteur exige des puissances de deux, et c'est le
    dernier quart, transparent, qui fait la difference ;
  * reecrit Data\\Genere\\Portraits.lua.

Une image nommee « _silhouette » devient le repli affiche pour un personnage
dont l'artwork n'est pas encore livre.

WoW ne lit ni PNG ni JPG, et il ne lit que ce qui se trouve dans le dossier de
l'addon : un portrait n'arrive donc chez les joueurs qu'avec la mise a jour.
"""
import io
import os
import re
import sys
import unicodedata

try:
    from PIL import Image
except ImportError:
    print("Il manque Pillow. Installe-le avec :")
    print(r"    C:\Users\Synestra\projects\NecroniconMock\.venv\Scripts\python.exe -m pip install Pillow")
    sys.exit(2)

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(RACINE, "Portraits")
ADDON = r"F:\WOW EPSILON\Epsilon\Epsilon\_retail_\Interface\AddOns\LesContesMalveillants"
SORTIE = os.path.join(ADDON, "ressources", "portraits")
REGISTRE = os.path.join(ADDON, "Data", "Genere", "Portraits.lua")

# 256 x 512 pese 512 Ko par portrait, contre 2 Mo en 512 x 1024. La carte fait
# 208 pixels de large a l'ecran : doubler la definition ne se verrait pas, mais
# se paierait a chaque mise a jour. Monter ces deux valeurs (en gardant des
# puissances de deux et le rapport 3/4) si un jour on affiche plus grand.
LARGEUR, HAUTEUR = 256, 512
UTILE = 384                      # hauteur reellement occupee : 384 / 512 = 0,75
EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga")
SILHOUETTE = ("_silhouette", "silhouette", "placeholder", "_placeholder")

ENTETE = """-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Convertir les portraits » a partir des images deposees
--  dans LesContesMalveillants\\Portraits. Toute retouche manuelle sera perdue
--  au prochain export.
--
--  Pour ajouter un portrait : deposer l'image (png / jpg), relancer l'outil,
--  publier. Les joueurs le voient a la mise a jour suivante.
-- ============================================================================

local _, LCM = ...
local Portraits = LCM.Portraits

"""


def identifiant(nom):
    """« Reika Shira.png » -> « reika_shira ». Sans accent, sans espace."""
    base = os.path.splitext(os.path.basename(nom))[0]
    base = unicodedata.normalize("NFD", base)
    base = "".join(c for c in base if unicodedata.category(c) != "Mn")
    base = base.lower().replace("'", "")
    base = re.sub(r"[^a-z0-9]+", "_", base).strip("_")
    return base or "portrait"


def cadrer(image):
    """Recadre au format 2:3 en gardant le haut, puis met a l'echelle."""
    image = image.convert("RGBA")
    large, haut = image.size
    vise = 2.0 / 3.0
    if large / haut > vise:
        # Trop large : on rogne les cotes, a egalite de part et d'autre.
        neuf = int(round(haut * vise))
        marge = (large - neuf) // 2
        image = image.crop((marge, 0, marge + neuf, haut))
    else:
        # Trop haut : on garde le haut, la ou se trouve le visage.
        neuf = int(round(large / vise))
        image = image.crop((0, 0, large, min(neuf, haut)))
    return image.resize((LARGEUR, UTILE), Image.LANCZOS)


def convertir(chemin, destination):
    toile = Image.new("RGBA", (LARGEUR, HAUTEUR), (0, 0, 0, 0))
    with Image.open(chemin) as image:
        toile.paste(cadrer(image), (0, 0))
    # TGA 32 bits non compresse : c'est ce que le moteur avale sans discuter.
    toile.save(destination, format="TGA", compression=None)


def ecrire_registre(portraits, silhouette):
    lignes = [ENTETE]
    if not portraits:
        lignes.append("-- Aucun portrait livre pour l'instant.\n")
        lignes.append("local _ = Portraits\n")
    else:
        for pid, libelle in portraits:
            lignes.append('Portraits.Add({ id = "%s", label = "%s" })\n'
                          % (pid, libelle.replace('"', "'")))
    if silhouette:
        lignes.append("\n-- Repli : affichee quand un personnage n'a pas encore son artwork.\n")
        lignes.append('Portraits.SetSilhouette("%s.tga")\n' % silhouette)
    io.open(REGISTRE, "w", encoding="utf-8", newline="\n").write("".join(lignes))


def main():
    apercu = "--apercu" in sys.argv
    if not os.path.isdir(SOURCES):
        os.makedirs(SOURCES)
        print("Dossier cree : %s" % SOURCES)
        print("Depose les artworks dedans, puis relance.")
        return 0

    fichiers = sorted(f for f in os.listdir(SOURCES) if f.lower().endswith(EXTENSIONS))
    if not fichiers:
        print("Aucune image dans %s" % SOURCES)
        print("Nomme chaque fichier d'apres le personnage, et « _silhouette.png » pour le repli.")
        return 0

    if not apercu and not os.path.isdir(SORTIE):
        os.makedirs(SORTIE)

    portraits, vus, silhouette = [], {}, None
    for fichier in fichiers:
        pid = identifiant(fichier)
        repli = os.path.splitext(fichier)[0].lower() in SILHOUETTE
        if pid in vus:
            print("  !  %s et %s donnent le meme identifiant (%s) — le second est ignore."
                  % (vus[pid], fichier, pid))
            continue
        vus[pid] = fichier
        libelle = os.path.splitext(fichier)[0]
        source = os.path.join(SOURCES, fichier)
        cible = os.path.join(SORTIE, pid + ".tga")
        marque = "   [silhouette de repli]" if repli else ""
        if apercu:
            with Image.open(source) as image:
                print("  -  %-28s %sx%s  ->  %s.tga%s"
                      % (fichier, image.size[0], image.size[1], pid, marque))
        else:
            convertir(source, cible)
            print("  ok %-28s ->  %s.tga  (%d Ko)%s"
                  % (fichier, pid, os.path.getsize(cible) // 1024, marque))
        if repli:
            silhouette = pid
        else:
            portraits.append((pid, libelle))

    if apercu:
        print("\nApercu seulement — rien n'a ete ecrit.")
        return 0

    ecrire_registre(portraits, silhouette)
    print("\n%d portrait(s)%s. Registre reecrit : %s"
          % (len(portraits), " + silhouette de repli" if silhouette else "", REGISTRE))
    print("Pense a publier pour que les joueurs les recoivent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
