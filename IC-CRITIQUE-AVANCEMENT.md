# IC Critique — chantier en cours

## Réalisé et testé

- Barèmes communs de fréquence, durée et déclenchement dans Equilibrage.
  Un déclencheur intrinsèque est inclus ; un effet instantané ne bénéficie
  pas du rabais d'une durée temporaire. Plancher : 1 IC.
- Compteurs purs par exemplaire (`IC.Charges`) : fenêtre glissante de
  24 heures, combat, tour, sans limite. Une lecture ne modifie rien.
  La consommation est explicite, après confirmation de l'effet.
- Définitions IC conservées dans les échanges d'objets, avec un corps
  sérialisé typé pour conserver les booléens et paramètres.
- Identités générées par exemplaire lors des écritures d'inventaire ;
  anciennes piles reprises sans changer leurs caractéristiques.
- Conservation testée : scission/fusion, retrait/dépôt, équipement,
  déséquipement, sélection entre deux armes identiques, sérialisation,
  échange simulé et extraction/remplissage du contenu d'un sac.
- Les sources et destinations de glisser-déposer des sacs et de la fiche
  transmettent les exemplaires. Équiper une pile entière est refusé :
  il faut en séparer une unité, pour ne pas supprimer les autres.

## Pas encore branché en jeu

Le module de charges n'est appelé par aucune action. Les tests d'inventaire
et d'échange ne constituent pas une validation du réseau complet des coffres.
Ce lot reste dans le dépôt de développement, pas dans les addons du jeu.

Prochaines étapes :

1. Finir la propagation dans les coffres et les sacs au sol (états diffusés,
   réservations, réponses tardives, annulations par identité). Revoir la
   création d'incarnations depuis un modèle PNJ pour ne pas cloner ses IDs,
   et négocier la compatibilité avec les clients sans identité d'exemplaire.
2. Catalogue Critique, configuration dans la forge et confirmation facultative.
3. Résolution critique avant résistances, synchronisation avec l'attaquant,
   soins corporels, bouclier, malus et déclencheurs.
4. Tests de bout en bout et installation dans les deux addons du jeu.

Le catalogue jouable reste vide tant que les effets ne sont pas exécutables.
La protection contre les rejeux réseau doit être assurée par le journal
d'actions ; le compteur seul ne garantit pas cette protection après expiration
de sa fenêtre, ni pour la fréquence sans limite.
