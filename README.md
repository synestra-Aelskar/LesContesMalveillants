# Les Contes Malveillants

Addon WoW (Epsilon) du système de jeu des **Contes Malveillants**. Il remplace
Necronicon : même campagne, mêmes règles, mais **écrit pour ce jeu-là** au lieu
d'être configurable à l'exécution.

C'est le choix qui structure tout le reste. Dans Necronicon, les fenêtres, les
catégories et les identifiants se négociaient à l'exécution ; presque tous les
bugs venaient de là — collisions d'identifiants, compendiums fantômes,
références non portables. Ici :

> **Aucune donnée de structure ne vit dans la sauvegarde.**
> La sauvegarde ne contient que ce que le joueur a saisi.

Ajouter une statistique, un type de dégât, une catégorie du menu, c'est modifier
le code et republier. C'est volontairement moins souple, et beaucoup plus solide.

---

## Installation

Deux dossiers, à déposer dans `Interface\AddOns` :

| Dossier | Pour qui | Contenu |
|---|---|---|
| `LesContesMalveillants` | tout le monde | l'addon |
| `LesContesMalveillants_MJ` | le MJ seulement | le contenu du maître du jeu |

Le compagnon MJ n'est pas un verrou : `LCM.IsMaster()` teste simplement sa
présence pour débloquer l'interface MJ. Un addon vit sur la machine du joueur,
cacher un bouton ne protège rien — **ce qui protège, c'est de ne pas livrer le
dossier**. L'outil de mise à jour « joueurs » ne l'installe pas.

## Commandes

```
/lcm            la liste des commandes
/lcm creer      créer un personnage
/lcm fiche      la fiche du personnage joué
/lcm personnages  choisir son personnage
/lcm fenetres   le menu des fenêtres (comme le bouton)
/lcm actions    la couronne du lanceur d'actions
/lcm sceau      montrer / cacher le sceau des actions
/lcm doc        la documentation en jeu
/lcm brouillons (MJ) le contenu créé en séance
/lcm atelier    (MJ) créer traits, races et objets en séance
/lcm debug      les traces
```

Organisation reprise de Necronicon et de son template :
- le **bouton** (36 px, déplaçable) : clic gauche, la colonne des fenêtres
  (dossiers Création personnage, Fiches personnages, Objets, Outils… du
  template) ; clic droit, la sélection du personnage ;
- le **sceau** : le lanceur radial des **actions** (Offensives, Supports,
  Compétences, Contrôles ; Animation pour le MJ), éteintes tant que la
  résolution des actions n'existe pas. Maj + glisser : le déplacer.

---

## Où en est-on

### Ce qui marche

**Le socle.** Schéma figé (`Core/Schema.lua` + `Data/Fiche.lua`), 156 champs,
8 onglets. Les entités — joueurs **et** PNJ, même modèle — ne stockent que leurs
valeurs : `{ id, name, icon, kind, values }`. Une valeur égale au défaut n'est
pas écrite. Un PNJ complet pèse une centaine d'octets, contre 8,6 Mo dans
Necronicon avant correctif.

**Le corps.** Règle du template Necronicon : chaque zone du corps vaut 30 %
des PV max, et les PV courants sont les PV max moins les blessures des zones.
L'humanoïde a les cinq zones du template (Tête, Torse, Bras, Jambes,
Internes) ; une morphologie déclare seulement combien elle a de chaque zone
(trois têtes, douze pattes…). Le stockage retient les **dégâts**, pas les
points restants.

**Les jets et les traits.** Un trait donne des bonus et un « avantage »
(relancer, garder le meilleur) sur des expertises nommées. Un trait ne peut
jamais toucher les six statistiques primaires — c'est une règle de jeu, donc le
code la refuse. La case d'avantage n'apparaît que si un trait l'accorde.

**La création de personnage** (`/lcm creer`). Sept étapes, budgets recalculés au
niveau courant, plafonds par ligne, boutons `R` / `-` / `+` / `M`, récapitulatif
repliable à gauche. Le moteur (`Core/Creation.lua`) ne connaît aucune fenêtre :
les règles sont testables sans rien dessiner.

**Le menu des fenêtres** et le **lanceur d'actions** (organisation du
template), la **sélection de personnage** (carrousel d'artworks), la
**documentation en jeu**, le **skin Ael'Raz'kah** : cadre, en-tête, onglets,
blocs et lignes repris du thème Necronicon avec ses mesures et son atlas
(`ressources/aelrazkah/widgets-reference.tga`).

**Les sorts du personnage.** Le grimoire personnel se remplit en jeu
(`Core/Sorts.lua`) : c'est la seule chose de la sauvegarde qui ne soit pas une
valeur de fiche, et c'est un choix assumé — un sort appris appartient à celui
qui l'a. Il se **cite dans le chat** comme un objet du jeu (`Core/Lien.lua`,
lien cliquable qui ouvre une infobulle) et se **partage** à quelqu'un
(`Core/Reseau.lua`). Un sort reçu reste en mémoire vive tant qu'on ne l'a pas
pris : rien n'entre dans une sauvegarde sans que son propriétaire le veuille.

**La fiche.** Icônes, sélecteur de canal, statistiques qui se lancent.
Les icônes ne sont pas choisies à vue : chaque ligne du **profil template** de
Necronicon porte la sienne, et elles ont été relevées entrée par entrée dans la
sauvegarde (`Data/Icones.lua`, `Core/Body.lua`). Adresse et Esprit sont des
**jets** (0-15), pas des nombres. Les résultats partent dans le canal choisi en
haut de la fenêtre — quatre, ceux où l'on joue : Local, Emote, Groupe, Raid.
Local n'envoie rien : un addon ne parle pas à la place du joueur.

**L'argent et les points.** La **bourse** du personnage (Écus, Crédits domiens,
Essences stellaires par défaut ; le MJ en ajoute), les **vendeurs** et les
**points de récolte**, avec le **stock partagé** repris de Necronicon : il
repousse tout seul, et quand deux versions divergent c'est la prise la plus
récente qui gagne, puis la régénération la plus récente, puis le plus petit
restant. Un achat **prélève la bourse** — l'onglet « Devises » de l'inventaire
n'a plus de raison d'être et a été retiré.

**Les outils du MJ.** Le **Panel MJ** consulte la fiche d'un joueur, **à sens
unique** : un joueur n'a aucun moyen de demander celle d'un autre, et celui
qu'on consulte en est prévenu. **Incarner** joue un PNJ : les instances sont
indépendantes, et toutes les fenêtres suivent la bascule. Le **compendium est
réservé au MJ** depuis le 1er octobre 2026 — il porte les PNJ, les résolutions
et les actions MJ, un joueur n'a rien à y lire, et sa race il la choisit à la
création. Les PNJ ne sont pas *cachés* au joueur : `Compendium_PNJ.lua` est
**livré dans le compagnon MJ**, pas dans l'addon de base. Masquer une entrée
d'interface ne protège rien, un addon vit sur la machine du joueur.

**Les paramètres.** Onglet Général (sceau, personnage joué, dépannage) et
onglet **Apparences** : opacité des fenêtres, taille de l'interface (50 =
normale), et les quatre habillages — Incritas (sans habillage), Necronicon (pas
encore porté, et il le dit), Ael'Raz'kah lourd et léger.

**Les chaînes d'outillage** : export du contenu créé en séance, conversion des
artworks, publication. Voir plus bas.

### Ce que la première séance en jeu a corrigé

Le 1er octobre 2026, premier passage dans le jeu. Cinq pannes, et **aucune
n'était visible au banc** — ce qui en dit plus long que les pannes elles-mêmes.

- **La création ne s'ouvrait plus.** La case de race était un cadre, avec un
  script `OnClick` dessus. Le jeu ne donne ce script qu'aux boutons, et l'erreur
  tombait pendant la *construction* de la fenêtre : rien ne s'ouvrait.
  Le banc, lui, acceptait n'importe quel script sur n'importe quoi. **Il refuse
  maintenant** `OnClick` et `RegisterForClicks` ailleurs que sur un bouton, avec
  le message du jeu — activé, il a reproduit l'erreur à la bonne ligne.
- **Les réglages d'apparence étaient invisibles.** `UI.Curseur` naît cachée (à
  l'origine c'est l'ascenseur), et l'écran posait `curseur.max = 100` à la main
  sans jamais appeler `Regler`, qui est ce qui la montre. Et la barre de
  sous-onglets n'était ancrée **que d'un côté** : `UI.Onglets` centre ses
  boutons sur le haut de la barre, donc sans largeur ils partaient hors de la
  fenêtre, d'où les thèmes inaccessibles.
- **Le curseur de taille partait tout seul.** Il appliquait l'échelle à chaque
  image, donc la fenêtre qui porte la barre grandissait sous la poignée — et
  surtout la course était **recalculée à chaque image** à partir d'une largeur
  qui venait de changer. La course est maintenant relevée au clic et ne bouge
  plus, et `UI.Curseur` accepte `auRelachement` : pendant le glissement seul le
  pourcentage suit, le lâcher applique. (Necronicon avait le même défaut.)
- **Les onglets de la création tenaient sur trois rangées** et mangeaient le
  tiers de la fenêtre. `UI.BandeauOnglets:Disposer` accepte maintenant
  `uneRangee` : chaque onglet reçoit la même part de la largeur et la police
  descend jusqu'à ce que le plus long libellé y tienne (jamais sous 9 — en
  dessous, c'est la fenêtre qu'il faut élargir).
- **Les deux colonnes d'expertises se chevauchaient**, conséquence directe du
  resserrement : la place du libellé et celle du total étaient écrites en dur,
  et ne tenaient plus dans une colonne plus étroite. Elles se calculent
  maintenant à partir de la colonne, et le total par ligne s'efface quand il
  n'y a plus la place — il est de toute façon dans le récapitulatif.

Et une remarque de forme qui valait une passe entière : **les fenêtres étaient
trop grandes.** Mesures de Necronicon pour comparer — paramètres en 388 × 600,
et aucune fenêtre au-delà de 780 de large. Resserrées : Paramètres 460 × 420 →
400 × 560, Création 1000 × 720 → 820 × 620, Sélection 860 × 540 → 720 × 470,
Système d'Aelskar 860 × 520 → 760 × 500, Métiers 720 × 600 → 620 × 540,
Vendeur / Ressources 640 × 460 → 560 × 420, Grimoire 790 × 470 → 700 × 460,
Atelier MJ 760 × 540 → 700 × 500.

### Ce qui reste à faire

Par ordre de ce qui bloque le plus :

- [x] **Les fenêtres du menu** (organisation du template). Branchées : Règles,
      Fiche, Santé (Physique, États, Maladies, Intangible),
      Expertises, Pénétration & Résistances, Statistiques (récapitulatif),
      Apprentissage, Équipements, Inventaires (Sacs, Saccoches ; sacs ouverts
      case par case), Métiers, Déplacement, Compendium / Système d'Aelskar
      — **réservé au MJ** —
      (25 catégories du template, édition MJ en brouillon), Grimoires (le hub
      du template : les grimoires qu'on possède — le sien et ceux qu'on reçoit —
      puis leurs sous-grimoires et leurs sorts, chacun avec son propre jet).
      Paramètres (affichage, personnage joué, dépannage : remettre les fenêtres
      à leur place, état du réseau), Panel MJ (le groupe, et la fiche de chaque
      joueur sur demande), Incarner (le catalogue des PNJ, leurs instances en
      jeu, et la bascule — toutes les fenêtres suivent), Vendeur et Ressources
      (offres, stock partagé qui repousse, récolte, et achat **prélevé dans la
      bourse**).
      **Bourse** (ajoutée à la structure du template : les devises du
      personnage, Écus / Crédits / Essences stellaires toujours visibles, les
      autres dès qu'il en a ; le MJ ajuste, le joueur lit).
      **Toutes les entrées du menu sont branchées.** « Création » a quitté le
      menu le 1er octobre 2026 : on crée un personnage depuis la sélection
      (clic droit sur le sceau, « + Créer un personnage »), là où l'on choisit
      déjà qui l'on joue.
- [x] **Le modèle du compendium.** Traits, races, objets, états, maladies,
      apprentissages : icône, description, bonus et avantage (catalogues,
      `Core/Catalogues.lua`), créés dans l'atelier. Les 41 statistiques de
      combat du template (`Data/Combat.lua`) sont des cibles de bonus.
- [ ] **Le réseau.** Le transport existe (`Core/Reseau.lua` : découpage sous
      les **255 octets**, renumérotation, recollage — c'est la limite qui
      cassait les invitations de combat dans Necronicon), et il porte le partage
      de sorts **et la consultation des fiches par le MJ** — à sens unique :
      un joueur n'a aucun moyen de demander la fiche d'un autre, et celui qu'on
      consulte en est prévenu. Restent : bandeau d'initiative, combat.
- [x] **L'objet.** `LCM.Objets` : arme, équipement, accessoire (1 / 5 / 5
      emplacements, `Equilibrage.emplacements`), bonus et avantage comme un
      trait. Créés dans l'atelier, équipés par le MJ dans « Équipement ».
      Reste à décider : bonus aux primaires, dégâts d'arme, inventaire (les
      « Emplacements 1 à 4 »).
- [x] **L'interface MJ de création de contenu.** L'atelier (`/lcm atelier`,
      ou « Compendium » dans le menu) crée et modifie les brouillons de traits
      et de races ; le contenu publié s'y affiche en lecture seule. Les objets
      attendent leur registre.
- [x] **L'onglet Traits de la fiche** : une carte par trait porté (coût,
      description, effets) ; le MJ ajoute et retire, le joueur lit. Un trait
      disparu reste affiché, marqué, sans effet.
- [x] **Les races** : celles du compendium du template sont importées
      (Insgardienne, Projet HTDT-02, ORC, Aelskardien), en plus de l'humain —
      décision du 1er octobre 2026, qui revient sur « humain seulement ».
      Toutes sont humanoïdes ; les autres morphologies s'utilisent via le
      champ `morphologie` d'une entité.
- [ ] **Les points eux-mêmes** : `Data/Genere/Points.lua` est vide. Les vendeurs
      et les filons viendront de l'atelier MJ comme le reste du contenu ; la
      forme d'un point est documentée en tête du fichier.
- [ ] **Un outil MJ pour l'expérience.** Le niveau est fixe à 5 pour les
      joueurs (seul le compagnon MJ ouvre la saisie) ; monter de niveau doit se
      gagner en jeu. Reste à écrire : donner de l'XP, et le passage de niveau
      qui en découle.
- [ ] **Les portraits** : deux livrés (Moon, ReikaShira) plus la silhouette de
      repli. En ajouter : déposer l'image dans `Portraits\`, lancer l'outil,
      publier.
- [ ] **La barre de recherche** vue sur l'écran Necronicon : rôle à décider.
- [ ] **La densité des vues de fiche.** Fiche, Santé, Expertises… sont en
      600 × 720 : la largeur est celle de la fiche de Necronicon (600), mais
      elles sont plus hautes. À reprendre avec un œil sur l'écran du jeu, pas
      sur un tableau de mesures.
- [ ] **Le mode joueur, en jeu.** Le banc sait enfin le jouer (`--sans-mj`),
      mais personne n'a encore ouvert l'addon **sans** le compagnon MJ dans le
      vrai jeu. C'est la moitié du produit.

### Ce qui est posé mais pas validé en jeu

- Les **effectifs des morphologies non humanoïdes** (quadrupède, ailé,
  aberration) sont des extensions de l'addon, absentes du template : à valider.
- Les **icônes d'Aile et de Queue** et celle du **Vol** : le template est
  humanoïde et ne compte que Terrestre et Nage, donc ces trois-là sont des
  choix de l'addon. Tout le reste vient du template, relevé entrée par entrée
  (`Data/Icones.lua`, `Core/Body.lua`).
- L'équilibrage et les formules (PV, fatigue, initiative, PA, déplacement,
  apports des primaires aux expertises) suivent le **template Necronicon**
  (voir `CLAUDE.md`). Les écarts voulus sont commentés dans
  `Data/Equilibrage.lua`. **L'initiative a été vérifiée en jeu le 1er octobre
  2026** : la lecture du template (des divisions) est la bonne.

---

## Travailler sur l'addon

### Le banc de test

Il n'y a **pas besoin de lancer WoW** pour vérifier son travail. Le banc charge
les `.toc` dans un Lua 5.1 avec une API WoW simulée (cadres, ancrages, tailles,
textes, visibilité, clics, molette, animations) et joue un scénario.

Il est dans **`Banc/`**, livré avec le dépôt. Une installation, une fois :

```
cd Banc
installer.cmd
lcm.cmd scenarios\lcm_test_creation.lua
```

Il trouve les dossiers d'addon tout seul — le dépôt lui-même si tu le lances
depuis un clone, ou le dossier que tu lui donnes avec `--addons`. Voir
`Banc/LISEZ-MOI.md`.

Les **30 scénarios** de `Banc/scenarios/` (liste dans `Banc/LISEZ-MOI.md`)
couvrent le socle, les règles du template, le corps, les PV, les traits, les
objets, l'atelier, la fiche, les fenêtres du menu, les personnages, la
création, les grimoires et les sorts, la bourse, le stock, les points, le
canal, l'incarnation, les paramètres et le skin. **Ils doivent tous être au
vert avant de publier.**

`--sans-mj` ne charge que l'addon de base : `LCM.IsMaster()` est faux, et on
voit ce que voit un joueur. Jusqu'au 1er octobre 2026 le banc chargeait
toujours le compagnon, et **la moitié de l'addon n'était jamais testée**. Les
scénarios qui pilotent l'atelier MJ échouent dans ce mode, c'est normal.

Le banc a déjà attrapé une dizaine de vrais bugs. Écrire le scénario en même
temps que le code n'est pas une politesse ici, c'est ce qui fait gagner du
temps.

**Ce qu'il ne voit pas.** Il ne calcule **aucune géométrie d'écran** :
`GetWidth()` ne rend que ce qu'on a posé avec `SetWidth`, jamais ce que des
ancrages donneraient. Une barre ancrée d'un seul côté a donc l'air correcte au
banc et part hors de la fenêtre en jeu. Si la largeur de ce que tu poses vient
de ses ancrages, vérifie-le toi-même — `largeurResolue` dans
`lcm_test_parametres.lua` montre comment.

### Publier

Tout l'outillage est dans `F:\WOW EPSILON\LesContesMalveillants` :

| Fichier | Ce qu'il fait |
|---|---|
| `Publier.bat` | copie les deux addons dans le clone, commit, push |
| `Publier - apercu (sans pousser).bat` | prépare tout sans rien envoyer |
| `Exporter les brouillons.bat` | transforme le contenu créé en séance en fichiers Lua |
| `Convertir les portraits.bat` | convertit les artworks en textures WoW |

La **version** est lue dans le `.toc` de l'addon : une seule source de vérité.

### Les artworks

WoW ne lit ni PNG ni JPG, et seulement ce qui se trouve dans le dossier de
l'addon : une image ne peut donc pas voyager par le réseau, elle part avec la
mise à jour. Déposer les images dans `LesContesMalveillants\Portraits`, nommées
d'après le personnage (`Reika Shira.png`), puis lancer
`Convertir les portraits.bat`. Une image nommée `_silhouette` devient le repli
affiché pour les personnages sans artwork.

### Le compendium

La fenêtre « Système d'Aelskar » (menu, à la racine) et le hub
« Compendium » (menu Outils) reprennent le compendium du template : ses 25
catégories, avec « PNJ » et « Fiches PNJ » fondus en une seule. Les catégories
et leurs champs sont dans `Data/Compendium.lua` ; le moteur
(`Core/Compendium.lua`) ne fait que lire les registres de contenu. Le MJ crée
et modifie les entrées en brouillon depuis la fenêtre (compagnon MJ,
`Compendium.lua`).

Le contenu de Necronicon a été importé « en brut » par
`Outils/importer_necronicon.py`, qui écrit `Data/Genere/Compendium_*.lua` et
`Data/Genere/Necronicon_Grimoires.lua` — des fichiers distincts de ceux de
l'export des brouillons. Il lit, sans jamais y écrire, les sauvegardes d'un
compte (`--sauvegardes <SavedVariables>`, par défaut le compte AKRX) : le
compendium tel que modifié en jeu, les PNJ vivants, les grimoires, et les
entrées d'un ancien compendium qui ne survivaient qu'en copie. Sans
sauvegarde, il retombe sur le pack (`--pack`). Relancer l'outil réécrit ces
fichiers, et seulement eux ; un tri et une refonte du contenu sont prévus.

### Le contenu créé en séance

Le MJ crée traits, races et objets **en jeu** ; ça vit dans les SavedVariables
du compagnon et c'est jouable immédiatement. Entre deux séances,
`Exporter les brouillons.bat` transforme ces brouillons en fichiers Lua propres
dans `Data\Genere\`, qui partent dans le dépôt. Tout le monde met à jour avant
la séance suivante.

Les fichiers de `Data\Genere\` portent un en-tête
**« NE PAS MODIFIER A LA MAIN »** : ils sont réécrits entièrement à chaque
export.

---

## Pour Claude

Si tu fais travailler Claude sur ce dépôt, lis-lui `CLAUDE.md` — il contient les
conventions du code, les pièges déjà rencontrés, et ce qu'il ne faut surtout pas
faire. Claude Code le lit tout seul s'il est à la racine.
