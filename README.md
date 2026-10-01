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

**Le socle.** Schéma figé (`Core/Schema.lua` + `Data/Fiche.lua`), 109 champs,
7 onglets. Les entités — joueurs **et** PNJ, même modèle — ne stockent que leurs
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

**Les chaînes d'outillage** : export du contenu créé en séance, conversion des
artworks, publication. Voir plus bas.

### Ce qui reste à faire

Par ordre de ce qui bloque le plus :

- [ ] **Les fenêtres du menu** (organisation du template). Branchées : Règles,
      Création, Fiche, Santé (Physique, États, Maladies, Intangible),
      Expertises, Pénétration & Résistances, Statistiques (récapitulatif),
      Apprentissage, Équipements, Inventaires (Sacs, Saccoches, Devises ; sacs ouverts case par case), Métiers, Déplacement, Compendium / Système d'Aelskar
      (25 catégories du template, édition MJ en brouillon), Grimoires (le hub
      du template : les grimoires qu'on possède — le sien et ceux qu'on reçoit —
      puis leurs sous-grimoires et leurs sorts, chacun avec son propre jet).
      Paramètres (affichage, personnage joué, dépannage : remettre les fenêtres
      à leur place, état du réseau), Panel MJ (le groupe, et la fiche de chaque
      joueur sur demande), Incarner (le catalogue des PNJ, leurs instances en
      jeu, et la bascule — toutes les fenêtres suivent), Vendeur et Ressources
      (offres, stock partagé qui repousse, récolte et achat).
      **Bourse** (ajoutée à la structure du template : les devises du
      personnage, Écus / Crédits / Essences stellaires toujours visibles, les
      autres dès qu'il en a ; le MJ ajuste, le joueur lit).
      **Toutes les entrées du menu sont branchées.**
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
- [ ] **Le paiement chez le vendeur.** Le prix s'affiche, le stock se décompte,
      mais rien n'est prélevé : la table règle. La bourse existe désormais
      (`Core/Bourse.lua`, `Debiter` / `Peut`) — il reste à décider si l'achat
      prélève tout seul.
- [ ] **L'onglet « Devises » de l'inventaire** n'a qu'**un** emplacement dans le
      template, donc la bourse tient ses propres soldes à côté. À trancher :
      cet onglet garde-t-il un rôle, ou disparaît-il au profit de la bourse ?
- [ ] **Les points eux-mêmes** : `Data/Genere/Points.lua` est vide. Les vendeurs
      et les filons viendront de l'atelier MJ comme le reste du contenu ; la
      forme d'un point est documentée en tête du fichier.
- [ ] **Les portraits** : aucun livré. Déposer les images et lancer l'outil.
- [ ] **Les icônes de ligne** (Force, Vitalité…) et la **barre de recherche**
      vues sur l'écran Necronicon : rôle et liste à décider.

### Ce qui est posé mais pas validé en jeu

- Les **effectifs des morphologies non humanoïdes** (quadrupède, ailé,
  aberration) sont des extensions de l'addon, absentes du template : à valider.
- L'équilibrage et les formules (PV, fatigue, initiative, PA, déplacement,
  apports des primaires aux expertises) suivent le **template Necronicon**
  (voir `CLAUDE.md`). Les écarts voulus sont commentés dans
  `Data/Equilibrage.lua`.
- **L'initiative est à vérifier en jeu** (décision du 1er octobre 2026 : on
  verra plus tard, mais ça reste à faire). Le template **divise** —
  `niveau/2 + esprit/2 + perception/2` — là où l'addon multipliait par 2 au
  départ. L'écart est important : une initiative quatre fois plus basse change
  l'ordre des tours. À confronter à une vraie fiche avant d'équilibrer le
  combat dessus.

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

Les scénarios de `Banc/scenarios/` (liste dans `Banc/LISEZ-MOI.md`) couvrent
le socle, les règles du template, le corps, les PV, les traits, les objets,
l'atelier, la fiche, les fenêtres du menu, les personnages, la création et le
skin. **Ils doivent tous être au vert avant de publier.**

Le banc a déjà attrapé une dizaine de vrais bugs. Écrire le scénario en même
temps que le code n'est pas une politesse ici, c'est ce qui fait gagner du
temps.

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
