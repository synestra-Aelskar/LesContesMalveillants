# Le banc de test

Il fait tourner l'addon **sans lancer WoW**. Il charge les `.toc` dans un Lua 5.1
avec une API WoW simulée, joue un scénario, et dit ce qui passe et ce qui casse.

C'est l'outil le plus utile du dépôt. Il a attrapé une dizaine de vrais bugs —
dont plusieurs qu'on n'aurait vus qu'après trois `/reload` et une séance gâchée.

## Installation

Une fois pour toutes :

```
installer.cmd
```

Ça crée un environnement Python local (`.venv`) et installe `lupa` (le Lua
embarqué) et `Pillow` (pour l'outil de conversion des portraits). Il faut
Python 3 sur la machine.

## Lancer un scénario

```
lcm.cmd scenarios\lcm_test_socle.lua
```

Le banc cherche les dossiers d'addon dans cet ordre :

1. l'option `--addons <chemin>` ;
2. la variable d'environnement `LCM_ADDONS` ;
3. un dossier parent qui contient déjà `LesContesMalveillants/` — donc **le dépôt
   lui-même**, si tu lances le banc depuis un clone ;
4. le chemin Epsilon habituel.

En pratique, pour tester ta copie de travail plutôt que celle du dépôt :

```
lcm.cmd scenarios\lcm_test_socle.lua --addons "C:\...\_retail_\Interface\AddOns"
```

Il annonce le dossier retenu en première ligne. Si tu vois passer des tests alors
que tu viens de casser quelque chose, c'est la première chose à vérifier.

## Les scénarios

| Fichier | Ce qu'il couvre |
|---|---|
| `lcm_test_socle.lua` | schéma, entités, valeurs, jauges, droits MJ, commandes, poids d'un PNJ |
| `lcm_test_corps.lua` | morphologies, parties du corps, disposition |
| `lcm_test_pv.lua` | points de vie, répartition, dégâts |
| `lcm_test_traits.lua` | traits, bonus, avantage, jets |
| `lcm_test_objets.lua` | objets : registre, emplacements, effets cumulés avec les traits, fenêtre d'équipement |
| `lcm_test_inventaires.lua` | l'inventaire du template : onglets Sacs / Saccoches / Devises, sacs posés et repris de l'ancien format, cases, quantités, soldes, refus ; la fenêtre (grille / liste, glisser depuis le compendium) et la fenêtre d'un sac (cases, menu clic droit, déplacer) |
| `lcm_test_metiers.lua` | les 31 métiers du template, paliers d'XP incrémentaux, bonus de jet, fenêtre Métiers (XP réservée au MJ) |
| `lcm_test_identite.lua` | l'identité Total RP 3 (nom RP, icône) reprise de Necronicon, bouton du menu, TRP3 absent ou défaillant |
| `lcm_test_regles.lua` | les formules du template, vérifiées à la main : apports aux expertises, déplacement, PA, fatigue, initiative, PV |
| `lcm_test_brouillons.lua` | contenu créé en séance par le MJ |
| `lcm_test_atelier.lua` | l'atelier MJ : saisie, refus, modification, suppression, doublons |
| `lcm_test_compendium.lua` | le compendium « Système d'Aelskar » : les 24 catégories, le contenu importé, la fenêtre (types, catégories, sous-catégories, tableau, colonnes, pagination, sélection, carte), l'éditeur MJ (création, refus, publié en lecture, Dup, suppression, modification groupée, connaissance, cheminement), le hub |
| `lcm_test_fiche.lua` | la fenêtre de fiche, construite depuis le schéma |
| `lcm_test_fiche_traits.lua` | l'onglet Traits : cartes, ajout / retrait MJ, trait disparu, lecture joueur |
| `lcm_test_menu.lua` | le lanceur d'actions (radial) et le menu des fenêtres du template |
| `lcm_test_document.lua` | la documentation en jeu : liste, page défilante, titres du modèle |
| `lcm_test_vues.lua` | les fenêtres du menu tirées de la fiche : registre, Santé, Expertise |
| `lcm_test_grimoires.lua` | les grimoires : le hub, la possession (le sien, ceux qu'on reçoit), les sous-grimoires, les sorts et leur jet |
| `lcm_test_sorts.lua` | les sorts du personnage : sauvegarde, éditeur, lien de chat, découpage sous 255 octets, partage et adoption |
| `lcm_test_parametres.lua` | les paramètres : sceau, remise en place des fenêtres, traces, état du réseau |
| `lcm_test_fiches_mj.lua` | la consultation des fiches par le MJ : paquet, droits, groupe, panneau, sens unique |
| `lcm_test_incarnation.lua` | incarner un PNJ : instances indépendantes, bascule, droits MJ, fenêtre |
| `lcm_test_personnages.lua` | profils, carrousel, portraits, suppression |
| `lcm_test_creation.lua` | **les règles** de création : budgets, plafonds, refus |
| `lcm_test_creation_ecran.lua` | l'écran de création : compteurs, R / M, récapitulatif |
| `lcm_test_skin.lua` | le cadre Ael'Raz'kah, l'empilement des fenêtres |

**Tous doivent être au vert avant de publier.** Pour les lancer d'affilée :

```
for %f in (scenarios\lcm_test_*.lua) do @lcm.cmd "%f" | findstr /C:"TOUT PASSE" /C:"ECHEC"
```

## Écrire un scénario

Copie n'importe lequel des douze. La forme est toujours la même :

```lua
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")   -- démarre l'addon

dire("== ce qu'on vérifie")
attendu("libellé lisible", valeur, attendue)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
```

Écris les libellés en français lisible : la sortie du banc doit se lire comme un
compte rendu, pas comme un journal de débogage.

## Ce que la simulation sait faire

Elle est **structurelle** : elle retient la hiérarchie, les ancrages, les
tailles, les textes et la visibilité — assez pour vérifier qu'une fenêtre est
bien construite, sans prétendre dessiner quoi que ce soit.

| Outil | À quoi ça sert |
|---|---|
| `__declencher("PLAYER_LOGIN")` | déclencher un événement |
| `frame:Click("RightButton")` | cliquer, bouton au choix |
| `frame:Molette(-1)` | la molette |
| `editbox:Saisir("texte")` | taper dans un champ |
| `__avancer(1)` | faire tourner les animations d'une seconde |
| `__textes(frame)` | tous les textes d'une fenêtre et de ses enfants |
| `__descendants(frame)` | tous les cadres enfants |
| `__sorties` | ce que l'addon a écrit dans le chat |
| `__sansCouleur(texte)` | enlever les codes couleur de WoW |
| `__addonsCharges["..."]` | simuler la présence d'un addon |

`Show`, `Hide` et `SetShown` déclenchent `OnShow` / `OnHide`, comme dans le jeu.

**S'il manque une fonction de l'API WoW, ajoute-la au banc** (`lcm_bench.py`),
jamais un contournement dans l'addon. Il ne doit exister aucun `if Mock then`
dans le code de l'addon — sinon on ne teste plus ce qui tourne en jeu.

## Ce que le banc ne fait pas

- Il ne dessine rien : une fenêtre peut passer tous les tests et être laide ou
  illisible. Le rendu se vérifie en jeu.
- Il n'écrit **jamais** dans les `SavedVariables` du jeu (`WTF/`). Il peut les
  lire pour relever une valeur, jamais les modifier.
- Il ne simule pas le réseau, ni le combat, ni les cadres protégés.
