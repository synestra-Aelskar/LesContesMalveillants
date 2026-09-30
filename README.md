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
/lcm menu       ouvrir la couronne du menu radial
/lcm sceau      montrer / cacher le sceau du menu
/lcm doc        la documentation en jeu
/lcm brouillons (MJ) le contenu créé en séance
/lcm atelier    (MJ) créer traits, races et objets en séance
/lcm debug      les traces
```

Le **sceau** est affiché en permanence. Clic gauche : la couronne. Clic droit :
la sélection du personnage. Maj + glisser : le déplacer.

---

## Où en est-on

### Ce qui marche

**Le socle.** Schéma figé (`Core/Schema.lua` + `Data/Fiche.lua`), 109 champs,
7 onglets. Les entités — joueurs **et** PNJ, même modèle — ne stockent que leurs
valeurs : `{ id, name, icon, kind, values }`. Une valeur égale au défaut n'est
pas écrite. Un PNJ complet pèse une centaine d'octets, contre 8,6 Mo dans
Necronicon avant correctif.

**Le corps.** Les PV ne sont pas un nombre mais une répartition sur des parties
du corps, engendrées depuis la **morphologie** de la race : on déclare un
effectif (combien de têtes, bras, jambes, queues, ailes) et les parties sont
créées et placées automatiquement. Une aberration à 3 têtes, 12 pattes et
2 queues fonctionne sans une ligne de code de plus. Le stockage retient les
**dégâts**, pas les points restants.

**Les jets et les traits.** Un trait donne des bonus et un « avantage »
(relancer, garder le meilleur) sur des expertises nommées. Un trait ne peut
jamais toucher les six statistiques primaires — c'est une règle de jeu, donc le
code la refuse. La case d'avantage n'apparaît que si un trait l'accorde.

**La création de personnage** (`/lcm creer`). Sept étapes, budgets recalculés au
niveau courant, plafonds par ligne, boutons `R` / `-` / `+` / `M`, récapitulatif
repliable à gauche. Le moteur (`Core/Creation.lua`) ne connaît aucune fenêtre :
les règles sont testables sans rien dessiner.

**Le menu radial**, la **sélection de personnage** (carrousel d'artworks), la
**documentation en jeu**, le **skin Ael'Raz'kah**.

**Les chaînes d'outillage** : export du contenu créé en séance, conversion des
artworks, publication. Voir plus bas.

### Ce qui reste à faire

Par ordre de ce qui bloque le plus :

- [ ] **Les fenêtres du menu.** « Fiche », « Équipement », « Santé » et
      « Expertise » sont branchées (les deux dernières sont des *vues* : trois lignes dans
      `Data/Vues.lua` qui désignent des morceaux du schéma). Le reste attend
      ses règles : Apprentissage, Métier, Emplacements 1 à 4,
      Compétences, Grimoires, Déplacement, et les outils MJ (Panneau MJ,
      Action d'emplacement, Incarner) apparaissent **éteints** et le disent au
      clic. « Compendium » ouvre l'atelier MJ.
- [ ] **Le réseau.** Rien n'existe encore : pas de partage MJ ↔ joueurs, pas de
      bandeau d'initiative, pas de combat. (Dans Necronicon, se souvenir que les
      messages d'addon sont **limités à 255 octets** — c'est ce qui cassait les
      invitations de combat.)
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
- [ ] **Les races** : humain seulement, sur décision de Syn'estra. Les autres
      morphologies s'utilisent via le champ `morphologie` d'une entité.
- [ ] **Les portraits** : aucun livré. Déposer les images et lancer l'outil.
- [ ] **Les icônes de ligne** (Force, Vitalité…) et la **barre de recherche**
      vues sur l'écran Necronicon : rôle et liste à décider.

### Ce qui est posé mais pas validé en jeu

- Les **parts en pourcentage** des morphologies sont des valeurs que Claude a
  posées, pas des règles de Syn'estra. À valider avant de s'en servir pour
  équilibrer.
- Tout ce qui touche à l'équilibrage vient de la feuille Necronicon et a été
  confirmé, **sauf** mention contraire dans les commentaires de
  `Data/Equilibrage.lua`.

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

Douze scénarios couvrent le socle, le corps, les PV, les traits, les brouillons,
la fiche, la silhouette, le menu, les personnages, la création (moteur et
écran) et le skin. **Ils doivent tous être au vert avant de publier.**

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
