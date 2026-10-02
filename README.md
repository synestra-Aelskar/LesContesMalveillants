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
/lcm combat     (MJ) la fenêtre de combat ; joueur : passer son tour
/lcm combat fin (MJ) terminer le combat
/lcm etats      les états temporaires portés ; « retirer <nom> »
/lcm incarner   (MJ) incarner un PNJ ; vide : reprendre sa place
/lcm debug      les traces
```

Organisation reprise de Necronicon et de son template :
- le **bouton** (36 px, déplaçable) : clic gauche, la colonne des fenêtres
  (dossiers Fiches personnages, Objets, Outils… du template ; les Règles sont
  dans Outils depuis le 2 octobre 2026) ; clic droit, la sélection du
  personnage ;
- le **sceau** : le lanceur radial des **actions** (Offensives, Supports,
  Compétences, Contrôles ; Animation pour le MJ). Chaque bouton joue sa
  résolution du compendium. **Compétences** est la seule catégorie dont le
  contenu se calcule : ce sont les sorts du personnage joué (`Core/Sorts.lua`),
  huit au plus — un éventail n'a pas neuf branches, et au-delà on ne choisit
  plus, on cherche. Un sort qui se lance se lance, les autres se citent dans le
  chat. Glisser (clic gauche) : le déplacer — le relâcher
  n'ouvre pas le menu.

---

## Où en est-on

### Ce qui marche

**Le socle.** Schéma figé (`Core/Schema.lua` + `Data/Fiche.lua`), 155 champs,
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

**Le combat** (2 octobre 2026, `Core/Combat.lua`, `UI/Combat.lua`,
`LesContesMalveillants_MJ/Combat.lua`). Repris de l'initiative de Necronicon,
réduit aux réglages que le Panel MJ des Contes utilisait : le MJ invite le
groupe (chacun accepte ou refuse, son **jet d'Initiative part avec sa
réponse**), ajoute les PNJ en jeu, et lance. Ordre du plus haut au plus bas,
tours et **3 rounds par tour**, annonces au raid, le MJ **incarne** le PNJ dont
c'est le tour. Le **bandeau** reprend celui de Necronicon (textures
`ressources/combat/`) ; « Passer le tour » ne s'allume qu'au tour du joueur
(et, chez le MJ, au tour d'un PNJ). Un joueur qui recharge redemande l'état ;
un combat ne survit pas au `/reload` du MJ.

**Les actions du radial** (`Core/Actions.lua`). Les dix-sept boutons jouent les
résolutions du compendium, importées de Necronicon : le **composeur** (questions,
coûts PA/PF, dégâts calculés en direct, **jeux de choix** enregistrés), les
**calculateurs**, les coûts **débités à la déclaration seulement** (annuler ne
coûte rien), la **déclaration** (jets annoncés au groupe), le **choix des
cibles** (soi, le groupe, les PNJ du combat et de la scène ; « addon non
confirmé » à côté de qui n'a pas répondu au ping). Les formules de Necronicon
(`{stat:…}`, `[[0.fiche.window_custom_7::…]]`) passent par une **table de
correspondance** vers notre fiche ; une référence inconnue vaut 0 et **le dit**.

**Chez la cible** (`UI/Resolution.lua`). « Vous êtes la cible de » : résoudre
(la **Défense (auto v3)** du template : Encaisser ou Parer, jet opposé —
« inadapté » à 0,8 —, réduction par résistances et constitution), puis
**répartir les dégâts** sur les zones et les Boucliers (perce-armure minimum en
santé, **émote de réponse**), et le compte rendu revient à l'attaquant. Ou bien
**dévier** l'action vers une autre cible, ou **proposer une intervention** à un
tiers (`Core/Reactions.lua`, le « Bloc D » de Necronicon). Un PNJ visé est
résolu par le MJ, sur la fiche du PNJ.

**Soins, contrôles, buffs, dissipation.** Le soin se répartit zone par zone et
guérit la cible ; Répulsion / Attraction / Permutation sont **narratives**
(« repoussé de 6 m ») ; Immobilisation, Entrave, Lévitation et les buffs /
débuffs du **constructeur** posent des **états temporaires**
(`Core/EtatsTemporaires.lua`) : ils comptent comme une source de bonus, vivent
quelques rounds du combat, se lisent dans **Santé › États**, se résistent
(débuff) ou s'acceptent (buff), peuvent **cumuler** (drain par round), être
**illimités** et se **guérir** par un jet. La **dissipation** retire ceux qu'on
bat, chez soi, chez un joueur ou sur un PNJ.

**La présence et la scène.** Un **ping** discret (`Core/Presence.lua`) dit qui a
l'addon, sur tout le serveur (un canal dédié, caché) ; on le note sans
péremption. Le choix des cibles reste limité au groupe. Les **PNJ en scène**
(`Core/Scene.lua`) : ceux que le MJ a mis en jeu dans Incarner, diffusés au
groupe — on cible un PNJ sans parcourir tout le catalogue.

**Le déplacement forcé.** Quelqu'un te repousse de six mètres : personne ne
compte six mètres à l'œil, et la bonne foi n'y change rien. `Demarrer(mètres,
raison)` ouvre une jauge chez celui qui encaisse et mesure à sa place
(`Core/DeplacementForce.lua`, `UI/DeplacementForce.lua`). Mécanique reprise de
Necronicon : la distance est celle qui te sépare de ton **point de départ**, à
vol d'oiseau — tourner en rond n'avance à rien — le relief sous une unité est
ignoré, et fermer la fenêtre interrompt la course. Un effet narratif la
déclenche quand il porte `effectForcedMove` ; le paquet le transporte sous
`fm`, et son montant devient les mètres.

Ce qu'on n'a **pas** repris : Necronicon finit par des commandes serveur
(`.mod speed`, `.aura`) pour clouer le personnage. Cela tient à leur serveur et
à leurs droits ; ici on annonce la fin, le joueur s'arrête.

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

- **Les icônes s'écrivaient par-dessus leur libellé** sur la fiche.
  `Fiche.Nom` a deux colonnes, avec icône et sans, et les trois constructeurs
  de ligne (stat, jauge, jet) posaient l'icône puis demandaient la colonne
  « sans icône ». Le banc le vérifie maintenant sur toutes les lignes de la
  fiche : remis en panne, il en comptait douze.

Et une remarque de forme qui valait une passe entière : **les fenêtres étaient
trop grandes.** Mesures de Necronicon pour comparer — paramètres en 388 × 600,
et aucune fenêtre au-delà de 780 de large. Resserrées : Paramètres 460 × 420 →
400 × 560, Création 1000 × 720 → 820 × 620, Sélection 860 × 540 → 720 × 470,
Système d'Aelskar 860 × 520 → 760 × 500, Métiers 720 × 600 → 620 × 540,
Vendeur / Ressources 640 × 460 → 560 × 420, Grimoire 790 × 470 → 700 × 460,
Atelier MJ 760 × 540 → 700 × 500.

Puis, le 2 octobre, la même remarque sur la **fiche** — alors que l'échelle
était déjà descendue à 76 % dans la sauvegarde. Ce n'était donc pas le réglage
mais la base : `UI.AelColonnes` faisait tout suivre la largeur, y compris la
hauteur de ligne et la taille du texte. Une fiche de 600 de large donnait des
lignes de 46 et du texte de 18.

**Les colonnes suivent la largeur ; le rythme vertical et le texte, non.**
C'est la règle que Necronicon applique sans la dire : ses fenêtres hors atlas
écrivent en 12 quelle que soit leur largeur, et ses lignes font 26. Plafonds
posés en conséquence — ligne 26, texte 12, icône 20, croix 24, titre 17 — et
les vues de fiche ramenées de 600 × 720 à **380 × 500**.

Deux pièges de mise en page sont tombés dans la foulée, tous deux invisibles
tant qu'on ne regarde pas l'écran :

- **Un libellé sans largeur ne s'arrête jamais.** « Points d'action » passait
  sous sa propre jauge. Les libellés sont maintenant bornés par la colonne qui
  suit, coupés plutôt que débordants — et la ligne porte le nom du template,
  **PA**, qui tient de toute façon. Idem pour « Point de vie », au singulier.
- **Les 24 unités de marge du gabarit ne sont pas du contenu.** Le gabarit
  arrête sa dernière colonne à 762 sur 786 ; reportées telles quelles, ces 24
  unités laissaient une bande vide entre le dernier bouton et le bord du cadre.
  Les colonnes de droite se calent désormais sur le **bord droit de la ligne**,
  largeurs toujours proportionnelles, seules les origines changent. Le banc
  vérifie l'égalité : dernier bouton + sa largeur = largeur de la ligne.

Au passage, la jauge des points de vie n'a pas de boutons : elle court jusqu'au
bord gauche du « R » des jauges d'en dessous, au lieu de laisser leur place
vide. Et **« PV max imposé » a été supprimé** : une surcharge MJ qui traînait
sur la fiche de tout le monde, alors qu'un PNJ dont les PV ne collent pas se
règle en changeant sa constitution. Le schéma passe de 156 à 155 champs ; trois
scénarios qui s'en servaient comme raccourci passent maintenant par la vraie
formule.

### Deux fenêtres retravaillées le 2 octobre

**Les Règles** ne se lisent plus derrière une bande de huit onglets sur trois
rangées. Leurs chapitres sont dans un **sommaire à gauche**, et sous le
chapitre ouvert, ses titres de blocs en sous-chapitres : cliquer un
sous-chapitre fait défiler jusqu'à son bloc. Seul le chapitre ouvert se déplie
— huit chapitres de cinq blocs feraient quarante lignes, et une table des
matières qu'on doit faire défiler ne sert plus à rien. La puce qui marque
l'endroit où l'on se trouve est **la gemme de l'atlas** et pas un losange tapé
au clavier : la police du jeu n'a pas ce signe et l'affichait en carré vide
(repli sur un chevron quand l'habillage n'a pas d'atlas). Elle suit le
**défilement**, pas seulement le clic : `UI.Defilement` prévient qui veut le
savoir à chaque mouvement. Et la fenêtre **se tire** (minimum 420 × 320) ;
c'est réservé aux vues en sommaire, parce qu'une page de fiche garde les
mesures de colonnes de son ouverture et que l'étirer ferait mentir ses
alignements — c'est écrit à côté de `page:Largeur`.

**Les primaires de la fiche** sont en deux blocs : **Habilités** (Adresse,
Esprit) et **Statistiques** (Force, Mystique, Perception, Constitution). La
coupure suit la mécanique : Adresse et Esprit sont les deux seules primaires
qui se lancent, leur ligne porte un dé et un bouton. Mélangées, deux lignes sur
six avaient une forme différente des autres. C'est fait dans le schéma, donc la
carte de PNJ et la consultation MJ suivent ; la création garde les six
ensemble, son budget est commun.

### Le lanceur et la sélection redessinés (2 octobre)

**Le lanceur d'actions** a ses propres icônes, peintes dans le style du
grimoire (`ressources/radial/icones/*.tga`, 128 × 128). Elles remplacent les
icônes du jeu ; les images de départ, les prompts (`sources.json`) et le script
de conversion (`preparer.py`) sont à côté. Le sceau s'anime en **livre qui
s'ouvre** (six poses, `grimoire-animation-1..6.tga`, puis
`grimoire-ouvert-v2.tga`), avec un sceau qui scintille et des particules ; les
boutons ont une lueur, des runes qui tournent et des étincelles. Les actions
passent de 34 à 52 px. **Glisser le sceau ne referme plus le menu.**
« Dégât MJ » n'a pas d'icône à lui : il porte le d20 peint pour « Résolution
Test MJ », qu'il a remplacé.

**La sélection de personnage** passe à 820 × 520. La liste de gauche défile
et montre, sous chaque nom, « Niveau N · En jeu ». Les cartes portent
« Niv. N » et « EN JEU » ; elles **glissent** d'un personnage à l'autre
(0,26 s), avec des boutons ‹ › et « Personnage x / n ». Le carrousel **ne
boucle plus** : il s'arrête au premier et au dernier.

À trancher : les images sources (environ 35 Mo) sont dans le dossier de
l'addon, donc livrées aux joueurs à chaque publication.

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
- [x] **Le réseau.** Le transport (`Core/Reseau.lua` : découpage sous les
      **255 octets**, renumérotation, recollage — c'est la limite qui cassait
      les invitations de combat dans Necronicon) porte le partage de sorts, la
      consultation des fiches par le MJ (à sens unique), et depuis le
      2 octobre 2026 : le **combat** et son bandeau, les **actions** (déclaration,
      défense, compte rendu, effets, dissipation, déviation, intervention), la
      **présence** de l'addon et la **scène** du MJ.
- [x] **Les boutons du radial** (2 octobre 2026) : les dix-sept jouent leur
      résolution de bout en bout au banc. Voir « Ce qui marche ».
- [ ] **Une séance de test à deux, en jeu**, sur tout ce qui précède : le banc
      vérifie la logique et les clics, pas l'écran ni le vrai réseau.
- [x] **Le déplacement forcé** (Répulsion, Attraction, intervention avec
      déplacement). Fait le 2 octobre 2026 — voir plus haut.
- [x] **La catégorie « Compétences » du radial** porte les sorts du personnage
      joué, huit au plus.
- [x] **« Résolution Test MJ »** a laissé sa place à « Dégât MJ » dans
      Animation, sur décision de l'utilisateur.
- [ ] **La jauge `#armure`** : les attaques citent une zone « armure » que la
      fiche n'a pas. Aujourd'hui la répartition le signale et se fait en santé
      et Boucliers. **Relevé du template le 2 octobre 2026** : aucune jauge n'y
      porte le tag `#armure`. Les jauges taguées sont « Boucliers »
      (`#bouclier`) et les cinq zones (`#sante #tete`…). Chaque pièce de la
      catégorie « Armures » a bien une jauge « Etat » (0 à 100), mais **sans
      tag** : dans Necronicon, `#armure` ne visait rien. Le brancher sur l'état
      des armures portées serait une règle nouvelle. **À décider.**
- [x] **La fenêtre Combat dans le Panel MJ** : un bouton « Combat » en haut à
      droite du Panel MJ l'ouvre (2 octobre 2026). Pas d'entrée de menu : le
      menu suit le template, qui n'a pas de fenêtre de combat, et Necronicon
      menait l'initiative depuis sa fenêtre du MJ. `/lcm combat` marche
      toujours.
- [ ] **Les actions MJ livrées aux joueurs** : `Compendium_Resolutions.lua` est
      dans l'addon de base, donc « Attaque MJ » & co sont chez les joueurs
      (ils ne peuvent pas les lancer, mais les ont). À ranger dans le
      compagnon si c'est un secret.
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
- [x] **La densité des vues de fiche.** Reprise deux fois le 2 octobre 2026 :
      plafonds de ligne, de texte, d'icône, de croix et de titre, colonnes de
      droite calées sur le bord, et vues ramenées à 380 × 500. **On est au
      bout de ce levier** : à cette largeur le texte des lignes calcule 10,3 px
      et le plancher de lisibilité est à 10. Pour gagner encore, il faut
      enlever quelque chose de la ligne, pas rétrécir.
- [ ] **Le vide au milieu des lignes de statistique.** Le libellé finit vers
      110, la valeur est calée à droite vers 336 : deux cents pixels de rien.
      Necronicon a le même trou — la colonne de valeurs est alignée pour qu'on
      la lise d'un trait. Deux sorties : rapprocher la valeur du libellé (la
      fenêtre descend vers 300, on perd l'alignement vertical des chiffres), ou
      garder l'alignement. **À trancher.**
- [ ] **Le découpage Habilités / Statistiques dans le récapitulatif.** La fiche
      sépare les deux depuis le 2 octobre ; la fenêtre Statistiques garde les
      six primaires dans un seul dossier. À uniformiser ou non, au choix.
- [ ] **Le mode joueur, en jeu.** Le banc sait enfin le jouer (`--sans-mj`),
      mais personne n'a encore ouvert l'addon **sans** le compagnon MJ dans le
      vrai jeu. C'est la moitié du produit. Depuis le 2 octobre 2026,
      `lcm_test_joueur.lua --sans-mj` ouvre au banc chaque entrée visible du
      menu et du lanceur sans relever d'erreur, et ne montre rien du MJ :
      reste à le voir à l'écran.

### Ce qui est posé mais pas validé en jeu

- Les **effectifs des morphologies non humanoïdes** (quadrupède, ailé,
  aberration) sont des extensions de l'addon, absentes du template : à valider.
- Les **icônes d'Aile et de Queue** et celle du **Vol** : le template est
  humanoïde et ne compte que Terrestre et Nage, donc ces trois-là sont des
  choix de l'addon. Tout le reste vient du template, relevé entrée par entrée
  (`Data/Icones.lua`, `Core/Body.lua`).
- **Tout le combat et toutes les actions du 2 octobre 2026** : bandeau
  (position, échelle, textures), composeur, constructeur (860 de large),
  fenêtres de la cible, de répartition, de réaction et de dissipation.
- Le **canal de présence** `LesContesMalveillants` : rejoindre un canal peut
  afficher « Canal rejoint » une fois ; et le jeu limite le nombre de canaux
  personnalisés (le groupe sert alors de secours).
- Deux **interprétations** de la table de correspondance : une ligne de
  mécanique du récapitulatif (`Recapitulatif#repulsion`) = les bonus portés sur
  cette mécanique ; les noms du constructeur rattachés à nos champs (Adresse,
  Mystique et Perception « - Camouflage » n'ont pas d'équivalent).
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

Les **43 scénarios** de `Banc/scenarios/` (liste dans `Banc/LISEZ-MOI.md`)
couvrent le socle, les règles du template, le corps, les PV, les traits, les
objets, l'atelier, la fiche, les fenêtres du menu, les personnages, la
création, les grimoires et les sorts, la bourse, le stock, les points, le
canal, l'incarnation, les paramètres et le skin, et depuis le 2 octobre 2026
le combat, les actions du radial et leurs réactions, la scène et la présence. **Ils doivent tous être au
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
