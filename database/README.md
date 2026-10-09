# Base commune des Contes Malveillants

Ce dossier est la source principale du contenu. Les archives des addons et les
fichiers `Data/Genere/Atelier.lua` ne sont que des versions distribuables.

## Organisation

Chaque contenu possède son propre fichier :

```text
entries/
  player/
    races/aelskardien.lua
    traits/attentive.lua
    objets/arc_court.lua
  mj/
    jeux/equilibrage_arme.lua
    pnj/identifiant.lua
tombstones/
  traits/ancien_trait.delete
```

Deux personnes qui créent deux entrées différentes modifient donc deux fichiers
différents. Git les fusionne automatiquement. Si elles modifient la même entrée,
le conflit est visible et doit être tranché au lieu d'écraser silencieusement le
travail de quelqu'un.

## Commandes quotidiennes

Depuis le dossier de travail `LesContesMalveillants`, utiliser en priorité :

- `Base - Recuperer.bat` avant de commencer ;
- `Base - Envoyer.bat` après avoir créé ou modifié du contenu en jeu ;
- `Publier.bat` après une modification du code de l'addon.

Ces raccourcis s'occupent de Git et indiquent `Interface/AddOns` au constructeur.
Les commandes ci-dessous restent disponibles pour le diagnostic avancé.

## Commandes avancées

WoW doit avoir écrit ses SavedVariables : faire `/reload` ou quitter le jeu avant
l'import.

```bat
lcm-db.cmd status
lcm-db.cmd import
lcm-db.cmd build
lcm-db.cmd sync
```

- `import` ajoute ou met à jour les brouillons locaux. Il ne supprime jamais une
  entrée simplement parce qu'elle n'existe pas dans la sauvegarde locale.
- `build` reconstruit les fichiers `Atelier.lua` joueur et MJ.
- `sync` effectue les deux opérations.
- Les suppressions sont volontairement explicites :

```bat
lcm-db.cmd delete traits identifiant_du_trait
lcm-db.cmd build
```

Une suppression peut être annulée avec
`lcm-db.cmd restore traits identifiant_du_trait`. Les anciens masques présents
dans une SavedVariables ne suppriment donc jamais silencieusement du contenu.

## Travail à deux avec Git

1. Double-cliquer sur `Base - Recuperer.bat` avant de travailler.
2. Créer ou modifier le contenu en jeu, puis faire `/reload`.
3. Double-cliquer sur `Base - Envoyer.bat`.
4. Après une modification de code, utiliser `Publier.bat` : il importe aussi
   les derniers brouillons avant son commit.

Les deux fichiers `Atelier.lua` générés ne doivent pas servir aux échanges Git :
deux builds parallèles modifieraient le même gros fichier et créeraient justement
le conflit que cette base cherche à éliminer. Ils sont reconstruits localement à
partir des petits fichiers fusionnés.

Les identifiants modernes `lcm_...` sont conçus pour être uniques entre les deux
machines. Une collision sur une ancienne entrée lisible indique généralement que
vous avez modifié le même contenu : ne choisissez pas une version au hasard.

## Sans Git

Échanger uniquement le dossier `database/entries` et les tombstones, en copiant
les fichiers dans la base existante sans supprimer les fichiers déjà présents.
Lancer ensuite `lcm-db.cmd build`. Ne jamais remplacer la base commune par un
`Atelier.lua` reçu dans une archive.
