# À reprendre

Ce fichier est pour l'IA qui reprend le travail quand on lui dit seulement
« Reprend ». Lis-le en entier, puis `CLAUDE.md`, puis la section « Ce qui reste
à faire » du `README.md`. Supprime ce fichier quand la liste ci-dessous est
vide (et dis-le).

## Avant de toucher à quoi que ce soit

1. `git fetch` puis `git log --oneline main..origin/main` : le binôme
   (Syn'estra) pousse souvent des commits « Version x.y.z - date ». S'il y en
   a, **dis-le à l'utilisateur et demande** avant de tirer par-dessus du
   travail local ; s'il n'y a rien de local, `git pull --ff-only`.
2. Ne modifie pas un fichier que le binôme vient de changer sans en parler
   d'abord. Ne pousse jamais sans qu'on te le demande. Commite quand on te le
   demande (l'utilisateur l'a demandé pour chaque lot terminé).
3. Lance tout le banc avant et après : depuis `Banc/`,
   `for s in scenarios/*.lua; do python3 lcm_bench.py "$s" 2>/dev/null | tail -1; done`
   (40 scénarios au vert au dernier commit). `--sans-mj` pour le mode joueur.
4. Quand c'est vert, copie dans le jeu :
   `rsync -a --delete <dossier>/ /mnt/e/Games/Epsilon/_retail_/Interface/AddOns/<dossier>/`
   pour `LesContesMalveillants` et `LesContesMalveillants_MJ`, puis `diff -rq`.

## Ce qui reste (demandé par l'utilisateur : « tout »)

Dans l'ordre :

1. **Le déplacement forcé.** Necronicon (`E:\Games\Epsilon\_retail_\Interface\
   AddOns\necronicon\Deplacement.lua`, `StartForcedDeplacement`) ouvrait une
   jauge qui décompte les mètres d'une Répulsion / Attraction (et d'une
   intervention « avec déplacement »). Chez nous :
   - écrire le module `LCM.DeplacementForce` avec `Demarrer(metres, raison)`
     (**pas** `LCM.Deplacement` : c'est la fonction de calcul de
     `Data/Fiche.lua`) ; `Core/Reactions.lua` l'appelle déjà s'il existe ;
   - le paquet d'effet (`DeclarerEffet` dans `Core/Actions.lua`) ne transporte
     pas encore `effectForcedMove` : ajouter un champ (ex. `fm = 1`) et, dans
     `Actions.Subir`, appeler `Demarrer(montant, nom)` pour un effet narratif
     qui le demande ;
   - la fenêtre : relire la mise en page de Necronicon et la reproduire (règle :
     on reprend ses mesures, on n'improvise pas).
2. **La catégorie « Compétences » du radial** (`UI/Radial.lua`, entrée
   `competences`, vide). Dans Necronicon, la barre « Compétences » portait les
   sorts du personnage (`RunGrimoireShortcutExec`). Les sorts sont dans
   `Core/Sorts.lua` (`Sorts.Liste(entity)`), lancés par `UI/Grimoires.lua`.
   La structure du radial est figée : proposer à l'utilisateur la forme (par
   exemple, la catégorie liste les sorts du personnage joué, 8 au plus) avant
   d'écrire.
3. **« Résolution Test MJ » / « Dégat MJ. »** : **à demander** à
   l'utilisateur. Le bouton actuel se propose l'épreuve à soi-même, paquet
   vide (fidèle à Necronicon, inutile) ; le vrai émetteur est `degat_mj`.
   Proposition : ajouter « Dégât MJ » dans la catégorie Animation.

Puis mettre à jour le `README.md` (« Ce qui marche », « Ce qui reste à
faire ») et commiter.

## Ce qu'il faut savoir du code ajouté le 2 octobre 2026

- `Core/Actions.lua` : le moteur des résolutions (composeur, calculateurs,
  déclaration, ciblage, défense, effets, constructeur de buff, dissipation,
  jeux de choix). Les références Necronicon passent par la table de
  correspondance en tête du fichier ; une référence inconnue est signalée.
- `Core/Reactions.lua` (déviation / intervention), `Core/EtatsTemporaires.lua`,
  `Core/Presence.lua` (ping par canal), `Core/Scene.lua` (PNJ en scène),
  `Core/Combat.lua`.
- Interface : `UI/Composeur.lua`, `UI/Resolution.lua` (toutes les fenêtres de
  la cible), `UI/Constructeur.lua`, `UI/Combat.lua`,
  `LesContesMalveillants_MJ/Combat.lua`.
- Nombres de règle : `Data/Equilibrage.lua` (`actions`, `puissanceMecanique`,
  `reactions`, `malusInadapte`, `combat`).
- La référence de Necronicon : `E:\Games\Epsilon\_retail_\Interface\AddOns\
  necronicon\` (ActionResolution.lua, Reactions.lua, Fiche.lua, Master.lua).
  Le profil du template se décode avec un petit script node (voir la mémoire
  « necronicon-reference ») ; on le lit, on n'écrit jamais dedans.
