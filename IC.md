# IC — fondations, étape 1

Les armes, armures, accessoires et outils ont un second budget indépendant.
Les livres, traits, races et états ne sont pas concernés. Aucun effet de combat
n'est livré à cette étape ; `Data/IC.lua` est un catalogue vide.

## Règles

| Palier | IC |
| --- | ---: |
| Rose | 0 |
| Vert | 3 |
| Bleu | 6 |
| Orange | 10 |
| Rouge | 15 |
| Violet | 21 |
| Noir | 50 |

Les nombres et le taux de conversion vivent dans `Data/Equilibrage.lua`.
Chaque rareté d'un jeu peut choisir son `palierIC` dans l'éditeur d'équilibrage.
Les sept identifiants historiques ont un palier de compatibilité ; ni le nom,
ni la couleur ne déterminent le budget. Une rareté personnalisée sans palier
garde sa forge classique, mais ne peut pas convertir d'IC.

Un IC entier converti donne 0,25 point de forge. Ce supplément est ajouté
après le multiplicateur des armes à deux emplacements et n'augmente pas le
plafond de remboursement des statistiques négatives. Les IC ne sont jamais
multipliés. Les points de forge ne peuvent pas être reconvertis en IC.

Une conversion non enregistrée peut être annulée ; une fois enregistrée, le
compteur ne peut plus diminuer. Passer à une rareté trop basse est refusé,
sans supprimer de propriétés ni raboter les statistiques. Convertir ne
répartit pas automatiquement les points gagnés.

## Données d'un objet

```lua
ic = {
    version = 1,
    palier = "bleu",
    convertis = 0,
    proprietes = {},
}
```

L'absence de `ic` signifie zéro dépense et zéro conversion. Aucun champ n'est
écrit sur un ancien objet au simple chargement. À l'édition, son budget est
déduit du palier de sa rareté ; ses statistiques restent celles de l'objet.
Les jeux d'équilibrage restent MJ, mais le bloc IC voyage avec l'objet public.

Les propriétés choisies contiennent leur identifiant, version, nom et
description de secours, coût validé, paramètres, fréquence et durée.
Une propriété existante inchangée garde son coût, même si le catalogue évolue.
Une entrée absente, désactivée ou d'une autre version est signalée
« indisponible », conservée, et n'est pas exécutée. Elle ne peut pas être
achetée à nouveau depuis la forge.
Un objet reçu d'un autre MJ peut conserver une propriété inconnue localement :
elle reste indisponible. Le partage MJ transporte le bloc IC sérialisé avec
ses types, comme la base publique ; les paramètres ne deviennent pas du texte.

## Ajouter ultérieurement une propriété

`LCM.IC.Declarer` enregistre une définition codée dans `Data/IC.lua` :

- `id`, `version`, `nom`, `description`, `categorie` ;
- `type` : `actif`, `passif`, `conditionnel` ;
- `coutBase`, `coutsFrequence`, `coutsDuree` ;
- `frequence`, `duree`, `instantane`, `parametres` et `restrictions` ;
- `effet` : identifiant du futur exécuteur ;
- `valider(choix)` : validation propre à la propriété, définie dans le code.

Fréquences : `heures24`, `combat`, `tour` avec `nombre` d'utilisations, ou
`permanent`. Durées : `instantanee`, `tours` avec `nombre`, `combat`,
`permanente`. Une durée temporaire est interdite pour une mécanique déclarée
instantanée. Un paramètre absent reste absent : aucune durée n'est imposée.

Les coûts supplémentaires sont indexés par type et nombre, par exemple
`["combat:1"]`. Une combinaison sans barème est refusée, jamais facturée zéro
par défaut. Les valeurs par défaut de la définition alimentent le choix
initial ; les futurs éditeurs de paramètres pourront appeler le même bilan
et le même validateur. Le sélecteur de la forge groupe déjà le catalogue par
catégorie et permet de retirer une propriété sélectionnée.

`IC.EVENEMENTS` réserve les noms des futurs points de branchement métier.
Ce n'est pas un moteur actif : aucun abonnement, effet ou compteur n'est
installé. Les usages consommés et effets temporaires ne doivent jamais être
rangés dans la définition partagée. L'identité des exemplaires et le stockage
des compteurs sont un préalable aux propriétés à charges indépendantes.

## Sauvegarde, synchronisation, tests

Le bloc est conservé par le registre Objets, la forge et l'atelier. La
validation centrale refuse un dépassement ou une diminution des IC convertis.
Les cartes affichent une section IC uniquement si des propriétés existent.

Google Sheets conserve le bloc dans la colonne **Definition Lua** de la
famille Objets ; aucune nouvelle feuille ni modification du service de
synchronisation n'est nécessaire. Les tests Python vérifient l'aller-retour
pour les quatre catégories et les anciennes entrées sans IC.

- `Banc/scenarios/lcm_test_ic.lua` : budgets, conversion, raretés, édition,
  réseau, conservation des propriétés retirées et absence d'effet actif.
- `Banc/test_gsheet_ic.py` : aller-retour Sheets hors ligne.

La présentation doit également être vérifiée dans WoW, dans les vues liste
et tableau de la forge, après mise à jour des deux addons et `/reload`.
