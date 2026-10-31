# Thèmes Affichage

Douze PNG créés avec l'outil image_gen intégré. Les requêtes exactes sont dans
`prompts.json`. Les textes restent rendus par l'addon, indépendamment du fond.

- Panneaux : bois, pierre, numérique, guilde, marchand, taverne.
- Affiches : papier, parchemin, missive, numérique, guilde, marchand.
- Écriture : classique, calligraphies élégante/médiévale/gothique, machine à
  écrire, numérique futuriste. Le choix « Selon le thème » sélectionne Rajdhani
  sur les écrans et Caudex sur les autres fonds.

`python Outils/affichages_blp.py` reconstruit les 12 BLP2/DXT5 1024 × 1024 dans
`LesContesMalveillants/ressources/affichages/` et vérifie leur relecture.
Les proportions paysage/portrait sont restituées par le lecteur Lua.
Les contours usés du parchemin sont détourés : l'extérieur de la feuille est
transparent, sans fond rectangulaire. La conversion vérifie la conservation
de cet alpha et l'opacité du centre. Toute future feuille déchirée doit suivre
la même règle. La retouche est documentée dans `parchemin-retouche.json`.
Le script de publication existant embarque automatiquement BLP, TTF et licences.

Les polices Great Vibes (OFL) et Special Elite (Apache 2.0) proviennent du dépôt
google/fonts ; leurs licences sont livrées dans le sous-dossier `polices`.
Les autres polices et leurs licences étaient déjà dans `ressources/bannieres/polices`.

Vérification :
`Banc/.venv/Scripts/python.exe Banc/lcm_bench.py Banc/scenarios/lcm_test_affichages.lua`

Planches de contrôle (BLP décodés et vraies polices, pas des captures WoW) :
`Banc/.venv/Scripts/python.exe Outils/affichages_apercu.py`.
Résultats dans `Banc/apercus/affichages/`.

Les anciens supports `provisoire` sont interprétés comme `bois`. Les anciennes
affiches sans thème utilisent le papier et l'écriture classique.
