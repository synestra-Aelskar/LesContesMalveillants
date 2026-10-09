# Base commune — marche à suivre

Le dépôt GitHub est la source principale. Les archives et les fichiers
`Atelier.lua` ne servent qu'à faire tourner ou distribuer les addons.

## Avant de travailler

1. Double-cliquer sur `Recuperer.bat` pour récupérer le code et le contenu du binôme.
2. Répondre `oui` si l'outil annonce des fichiers à remplacer.
3. Lancer WoW, ou faire `/reload` s'il était déjà ouvert.

`Recuperer.bat` reconstruit automatiquement les fichiers de contenu depuis la
base commune.

## Après avoir créé ou modifié du contenu en jeu

1. Faire `/reload` dans WoW afin d'écrire les SavedVariables.
2. Fermer WoW est encore plus sûr, mais n'est pas obligatoire après le `/reload`.
3. Double-cliquer sur `Base - Envoyer.bat`.
4. Attendre le message `Base commune envoyée sur GitHub`.

Les brouillons deviennent alors de petits fichiers indépendants. Deux créations
différentes se fusionnent sans écraser le travail de l'autre.

## Après avoir modifié le code de l'addon

1. Faire `/reload` dans WoW.
2. Double-cliquer sur `Publier.bat`.

La publication importe aussi les derniers brouillons avant de copier et envoyer
les addons. Si la base avait déjà été importée sans être envoyée, l'outil refuse
de continuer au lieu de la supprimer.

## Si un outil refuse

- `Le dépôt a avancé` : lancer `Recuperer.bat`, vérifier le résultat, puis recommencer.
- `La base contient des changements non envoyés` : lancer `Base - Envoyer.bat`.
- Conflit sur une même entrée : ne choisir aucune version au hasard. Les deux MJ
  ont modifié exactement le même contenu ; décider ensemble de la version à garder.
- Échec d'identification GitHub : se connecter au compte autorisé sur le dépôt.

## À ne plus faire

- Ne plus échanger `Atelier.lua` à la main.
- Ne plus remplacer tout l'addon avec l'archive du binôme.
- Ne plus utiliser `Exporter les brouillons.bat` comme méthode de partage.
- Ne jamais supprimer le dossier `.publication` : c'est le clone Git local.
