# Ouvrages BLP — 21 octobre 2026

Sources adaptées du journal de quête de l'utilisateur :
`Omega_Hub/Modules/Quest/Media/Book/BindingEdges` et
`Omega_Hub/Modules/Quest/Tools/book_animation.py`.
Les deux SVG de référence sont conservés ici. Les motifs, les palettes et
le grain du cuir sont définis dans `Outils/livres_sources.js`.

Quatre modèles autonomes sont livrés : `chronique`, `astral`, `herbier`, `necronicon`.
Le Necronicon conserve le cuir noir, les ferrures dorées et les crânes de
l'ancien lecteur. Ses sources PNG ont été retravaillées avec imagegen intégré,
puis normalisées et converties en BLP. Les prompts sont dans `necronicon-prompts.md`.
Chaque modèle a une couverture, une double page, 24 poses d'ouverture et
16 poses de feuilletage. La fermeture parcourt l'ouverture à l'envers ;
le retour de page utilise le miroir du feuilletage. La note possède son
papier et une séquence de retournement de 16 poses.

Tous les visuels utilisés par le nouveau lecteur sont des BLP2 DXT5.
Les atlas font 2048 × 2048 : quatre poses de 1024 × 1024, affichées à
940 × 650 unités. Couvertures et notes : 512 × 1024, affichées à 470 × 650.
Les zones de texte restent natives : titre en haut de couverture, sous-titre
sous le motif, pages de 355 unités avec corps de 18, 21 ou 24 points.
Le Necronicon utilise des pages de 310 unités pour laisser ses ferrures libres,
et une zone de couverture sous le pendentif. Les numéros et le total sont
portés par chaque page pour dégager le crâne au pied de la reliure.

Les atlas du modèle courant sont préparés avant le mouvement. Le texte
disparaît brièvement, le livre entier est animé, puis le texte revient.
Le contenu du compendium et sa pagination ne sont pas modifiés par l'animation.
Les anciens ouvrages sans champ `modele` utilisent `necronicon`, y compris
à l'ouverture de l'éditeur. Les nouveaux ouvrages ont un modèle explicite.

## Régénération

Depuis la racine du dépôt (Node et Python avec Pillow) :

```powershell
npm install --prefix Outils/.livres-deps sharp
python Outils/build_livres.py
Banc/.venv/Scripts/python.exe Outils/livres_apercu.py
```

Les PNG, SVG intermédiaires et GIF issus des BLP décodés sont dans
`rendus/<modele>/` (ignoré par Git). Les fichiers livrés se trouvent dans
`LesContesMalveillants/ressources/livres/<modele>/`. L'outil de publication
existant copie récursivement ces BLP.

Les compositions de contrôle sont dans `Banc/apercus/livres/` : positions,
polices et textes lus dans le lecteur Lua, dessinés avec Pillow sur les BLP
décodés. Ce sont des aperçus hors jeu, pas des captures du client WoW.

## Vérification

```powershell
Banc/lcm.cmd scenarios/lcm_test_livres.lua
Banc/lcm.cmd scenarios/lcm_test_livres_animation.lua
Banc/lcm.cmd scenarios/lcm_test_livres_immersion.lua
Banc/lcm.cmd scenarios/lcm_test_livres_joueur.lua
python Banc/test_gsheet_livres.py
```

Le scénario d'animation vérifie les quatre modèles, la présence des textures,
les interruptions, les chargements retardés, la fermeture, les notes et les
textes longs. La fluidité réelle et le rendu GPU restent à vérifier dans WoW.
