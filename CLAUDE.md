# Instructions pour Claude

Salut. Tu travailles sur **Les Contes Malveillants**, l'addon WoW du système de
jeu de Syn'estra et de son binôme. Ce fichier te donne les conventions et, plus
utile, **les pièges déjà payés** — ils ont tous coûté un aller-retour en jeu.

Lis d'abord le `README.md` pour l'état des lieux. Ici, on parle du code.

## La règle qui commande tout

> **Aucune donnée de structure ne vit dans la sauvegarde.**

L'addon précédent (Necronicon, 175 000 lignes) laissait l'utilisateur définir
ses fenêtres, ses catégories et ses identifiants à l'exécution. Presque tous ses
bugs venaient de là. Ici, la structure est **figée dans le code** et la
sauvegarde ne contient que ce que le joueur a saisi.

Concrètement, quand on te demande « ajoute une statistique » : tu l'ajoutes dans
`Data/`, tu republies, et les joueurs la voient à la mise à jour. Tu ne
construis pas un écran pour la créer à la volée. Si une demande t'amène à écrire
de la structure en sauvegarde, dis-le et propose l'autre chemin.

## D'où viennent les règles

La référence est le **template Necronicon** « Template Fiche LVL 5 - Contes
Malveillants V2 », livré dans le plugin
`Necronicon_System_Les_contes_Malveillants_MJ` (entrée TEMPLATE de son
compendium). Ses fenêtres Équilibrage, Création et Expertises donnent les
nombres et les formules ; `Data/Equilibrage.lua` les recopie en clair, en
signalant chaque écart voulu (les coquilles du template sont corrigées, et dites).

Quand une règle manque, on la cherche là avant de la demander — et on ne
l'invente jamais.

## Organisation

L'ordre du `.toc` **compte**, et il est le suivant :

```
Core/    infrastructure (Init, Log, Events, Commands)
         puis registres  (Schema, Entities, Personnages, Portraits,
                          Body, Traits, Roll, Creation, Documents)
Data/    le contenu      (Equilibrage d'abord, il alimente les autres)
Data/Genere/             engendré par l'outil, jamais édité à la main
UI/      Kit, Skin, puis les écrans
```

- Un **registre** vit dans `Core/`, jamais dans le fichier d'interface : sinon
  `Data/*.lua`, chargé avant `UI/*.lua`, ne le trouve pas.
- `Core/Commands.lua` définit `LCM.AddCommand`, donc il précède tout ce qui
  enregistre une commande.
- **Un module de `Core/` ne peut pas capturer `LCM.Equilibrage` au chargement**
  (Core se charge avant Data). Le résoudre au premier appel — voir la fonction
  `Eq()` dans `Core/Creation.lua`.

### Les quatre endroits où poser une chose

| Tu ajoutes… | Ça va dans |
|---|---|
| un chiffre d'équilibrage | `Data/Equilibrage.lua`, **et nulle part ailleurs** |
| un champ de fiche | `Data/Fiche.lua` (ou `Types.lua`, `Expertises.lua`, `Mecaniques.lua`) |
| un widget d'interface | `UI/Kit.lua`, jamais dans un écran |
| une fenêtre du menu qui montre une partie de la fiche | `Data/Vues.lua` (une vue, pas un écran) |
| du contenu (trait, race, objet) | créé en jeu par le MJ, puis exporté vers `Data/Genere/` |

**Aucune formule ne code un nombre en dur.** Si tu écris `2.5` dans un calcul,
c'est qu'il manque une entrée dans `Equilibrage`.

## Le banc de test

Tu peux — et tu dois — vérifier ton travail **sans lancer WoW**.

```
cd Banc
installer.cmd                              (une seule fois)
lcm.cmd scenarios\lcm_test_creation.lua
```

Le banc trouve les dossiers d'addon tout seul : le dépôt s'il tourne depuis un
clone, sinon `--addons <chemin>` ou la variable `LCM_ADDONS`. Il annonce en
première ligne celui qu'il a retenu — **lis-la** avant de conclure quoi que ce
soit d'un test qui passe.

Le banc (`Banc/lcm_bench.py`) charge les `.toc` dans un Lua 5.1 (lupa) avec
une API WoW simulée : hiérarchie de cadres, ancrages, tailles, textes,
visibilité, clics (`frame:Click("RightButton")`), molette (`frame:Molette(-1)`),
saisie (`editbox:Saisir("texte")`), animations (`__avancer(1)`), `OnShow` /
`OnHide`, événements (`__declencher("PLAYER_LOGIN")`).

Conventions des scénarios : une fonction `attendu(libellé, obtenu, voulu)`, des
sections annoncées par `dire("== …")`, et une dernière ligne `TOUT PASSE` ou
`n ECHEC(S)`. Copie n'importe lequel de `Banc/scenarios/` pour démarrer.

### ⚠️ Le code de retour ment

**Plusieurs scénarios annoncent `n ECHEC(S)` et sortent quand même avec 0.**
Si tu comptes les rouges sur `$LASTEXITCODE` ou `errorlevel`, tu verras un banc
bien plus vert qu'il ne l'est. Ça a coûté plusieurs comptes rendus faux le
9 octobre 2026.

Compte sur le **texte**. En PowerShell :

```powershell
Get-ChildItem scenarios -Filter "lcm_test_*.lua" | ForEach-Object {
  $out = cmd /c ".\lcm.cmd `"scenarios\$($_.Name)`"" 2>&1 | Out-String
  if (($out -match "ECHEC\(S\)") -or ($out -match "ERREUR dans le scenario")) { $_.Name }
}
```

Si tu touches au banc, fais plutôt en sorte que chaque scénario propage son
code de retour — ce serait le vrai correctif.

### L'état au 10 octobre 2026 : 38 verts, 24 rouges

Le banc **n'est pas au vert**, et ce n'est pas une négligence : la plupart des
rouges sont des attentes devenues fausses après des changements voulus. Avant
de « réparer » quoi que ce soit, situe l'échec dans l'une de ces familles.

**1. Le barème de la forge bloque les fixtures.** De vrais jeux d'équilibrage
sont publiés depuis le 6 octobre. Or le barème **bloque** l'enregistrement
(décision du 3 octobre), et les fixtures créent des traits et des objets sans
déclarer de `forge`. D'où « accepte = false » un peu partout : `atelier`,
`brouillons`, `compendium`, `forge`, `objets`, `fiche_traits`. Le correctif est
de donner une `forge` aux fixtures, avec des bonus qui tiennent dans le pool —
pas de desserrer le garde-fou.

**2. Des nombres d'équilibrage ont changé.** PV 42 → 53, armure 2/12 → 10/20,
sauts, poids, métiers. Les tests encodent les anciens. **Ne les rebase pas à
l'aveugle** : demande lequel fait foi. Un test qu'on aligne sur le code ne
teste plus rien.

**3. On a ajouté des choses.** Onglets, catégories du radial, champs de fiche,
mécaniques. Ceux-là se rebasent sans risque — c'est déjà fait pour les comptes
connus.

**4. De vraies régressions.** Il y en a eu, et elles se cachaient dans le lot :
une insertion tombée dans le mauvais `Habiller` faisait planter la fiche, une
pièce d'armure brisée protégeait encore. Les deux sont corrigées. C'est
précisément pour ça qu'on ne rebase pas en masse.

**Quand tu casses un scénario** : dis si c'est un vrai bug ou une attente
devenue fausse, et dans le second cas **écris pourquoi le nombre a bougé** dans
le test. Un chiffre nu qu'on a changé sans raison écrite redeviendra un mystère.

Si le banc manque d'une fonction de l'API WoW, **ajoute-la au banc** (`Banc/lcm_bench.py`) plutôt que
de contourner dans le code de l'addon. Il ne doit y avoir aucun `if Mock then`
dans l'addon.

⚠️ **Le banc n'écrit jamais dans les SavedVariables du jeu** (`WTF/`). Il peut
les lire pour relever une valeur d'équilibrage ; il n'écrit jamais dedans.

## Les pièges déjà payés

Ceux-là ont tous cassé quelque chose pour de vrai. Relis-les avant de chercher
un bug bizarre.

**Lua 5.1 — une variable déclarée avant une boucle est partagée par toutes les
fermetures créées dedans.**

```lua
local index = 0
for _, categorie in ipairs(liste) do
    index = index + 1
    bouton:SetScript("OnClick", function() Truc(index) end)  -- ✗ tous à la même valeur
end
```

Capture la valeur de l'itération (`local id = categorie.id`), jamais le
compteur. Les huit en-têtes du récapitulatif repliaient tous la dernière
catégorie à cause de ça.

**`local a, b = f and f(x)` est ajusté à UNE valeur.** Le royaume était
silencieusement perdu dans `LCM.PlayerId()`.

**Un accesseur de lecture ne doit rien créer.** `entity.traits = entity.traits or {}`
dans un getter sème des tables vides dans la sauvegarde. Sépare lecture et
écriture (`OwnedIds` vs `OwnedIdsForWrite`), et efface la table dès qu'elle
redevient vide.

**Un second `SetPoint` s'ajoute au premier, il ne le remplace pas.**
`ClearAllPoints()` avant de ré-ancrer.

**Dans WoW, un enfant créé plus tard se dessine devant.** L'habillage
(`UI/Skin.lua`) est donc posé au niveau de la fenêtre elle-même
(`SetFrameLevel(parent:GetFrameLevel())`), sinon les ornements des coins
recouvrent le bouton de fermeture — c'est arrivé.

**Un composant qui se rafraîchit lui-même doit prévenir son conteneur**
(`onChange`), sinon le total affiché reste sur l'ancienne valeur.

**Les messages d'addon sont limités à 255 octets.** Hérité de Necronicon, où ça
cassait les invitations de combat dès deux joueurs exclus.

**Les textures doivent avoir des dimensions en puissances de deux** et être
listées dans la copie de publication (elles ne sont pas dans le `.toc` : elles
sont chargées par leur chemin depuis le Lua). Sans ça, WoW affiche des carrés
verts.

**Écrire du Lua ou du Python par un heredoc bash mange les antislashs** — un
`\\n` arrive comme vrai saut de ligne et casse la chaîne. Utilise l'outil
d'écriture de fichier, ou construis les chaînes avec `chr(92)`.

## Le ton du code

Regarde n'importe quel fichier existant : tu verras des commentaires qui
expliquent **pourquoi**, pas ce que fait la ligne d'en dessous. Garde ça. Un
commentaire utile ici, c'est « le stockage retient les dégâts, pas les points
restants — si le total de PV change, les blessures restent cohérentes », pas
« boucle sur les parties ».

Le code est en français (identifiants, commentaires, messages), **sans accents
dans les identifiants**, avec accents dans les libellés affichés. Les
identifiants de champ ne bougent jamais une fois publiés : ce sont eux que
référencent les sauvegardes existantes.

Un refus doit **dire pourquoi** et ne rien corriger en douce. Exemple : une
valeur au-dessus de son plafond reste affichée, en rouge, et bloque la
création ; on ne la rabote pas dans le dos du joueur.

## Ce qu'il ne faut pas faire

- **Ne supprime jamais de données sur l'heuristique « rien ne le référence ».**
  Ça a effacé un PNJ vivant dans Necronicon. Une purge automatique a été retirée
  pour cette raison ; il ne reste qu'un bouton manuel.
- **N'édite pas `Data/Genere/*.lua` à la main** : ils sont réécrits entièrement
  au prochain export.
- **Ne pousse pas sur le dépôt sans qu'on te le demande**, et jamais avec les
  douze scénarios en échec.
- **Ne recopie pas du Necronicon tel quel.** Ce qui est repris (boîte à outils
  UI, skin, lanceur radial) doit être relu et adapté. C'est toute la raison
  d'être de cet addon.
- Ne crée pas de frames pendant un rendu de façon paresseuse : crée-les une
  fois, repositionne-les ensuite.

## Ce qui a été ajouté début octobre

De quoi ne pas réinventer ce qui existe, ni casser une règle sans le savoir.

**L'état et les vies d'un objet** (`Core/Objets.lua`). Chaque arme, armure et
accessoire a un **état** (`EtatMax` / `Usure`) et des **vies** données par sa
rareté, c'est-à-dire la couleur de son titre (`Equilibrage.viesParRarete`). À
zéro d'état, l'objet **se brise** : il perd une vie, reste porté et reparable.
Il n'est détruit que s'il tombe à zéro sans vie. Un objet brisé n'apporte plus
rien et ne protège plus.

Et **ce qu'un objet apporte suit son état** : −20 % d'état, −20 % de
statistiques, arrondi au supérieur sur la valeur absolue. La règle passe par
`Effets.Source(..., apport)` — une source d'effets peut moduler ce qu'elle
donne, et seule la famille des objets s'en sert.

**Le dot** (`Core/Dot.lua`). Un état qui grignote une jauge à chaque round. Sa
seule subtilité : trois jauges sont **uniques** (bouclier, PA, fatigue) et se
grignotent toutes seules ; les PV et l'état d'armure sont **zonés**, donc le dot
n'y touche pas et pose une *note à jouer* que la cible applique. Les stacks
partagent un `rand` qui baisse d'un point par round, et une dissipation en
retire `score − rand + 1`. Il voyage par le même paquet `etat` que les buffs,
avec un champ `dt`. **L'action et son bouton radial n'existent pas encore.**

**Les réglages d'équilibrage** (`Core/Reglages.lua`, onglet Équilibrage du Panel
MJ). Changer un nombre du jeu en séance, par son **chemin** :
`Reglages.Definir("puissanceMecanique.parMecanique.perce_armure.base", 90)`.
Le fichier reste la référence ; la surcharge passe par-dessus au chargement, se
diffuse au groupe — sinon le MJ et ses joueurs ne jouent pas au même jeu — et
s'exporte dans `database/reglages/`, un fichier par chemin. Une surcharge
devenue identique au fichier s'oublie toute seule.

**L'échange entre joueurs** (`Core/Echange.lua`). On lâche un objet sur
quelqu'un ; s'il a l'addon, une fenêtre s'ouvre des deux côtés. Ce qu'on offre
**quitte le sac tout de suite** (mise en gage) et sait revenir ; tout changement
de contenu remet les deux accords à zéro.

**Un brouillon recouvre une entrée publiée** (`MJ/Brouillons.lua`). Modifier du
contenu publié tenait le temps de la séance puis disparaissait au `/reload` :
la boucle de chargement n'avait pas ce cas. Elle l'a maintenant, et garde une
copie de l'original pour que supprimer le brouillon la rende au lieu de
l'effacer.

## Le partage MJ / joueurs

`LesContesMalveillants_MJ` est un **aiguillage, pas un verrou** :
`LCM.IsMaster()` teste sa présence. Un addon vit sur la machine du joueur — rien
de ce qu'on lui envoie ne lui est inaccessible. Ce qui protège un secret, c'est
de **ne pas livrer le dossier**, et l'outil de mise à jour « joueurs » ne
l'installe pas. Si on te demande de « cacher » quelque chose aux joueurs dans
l'addon joueur, dis que ça ne protège rien et propose l'autre chemin.

---

Bon courage. Si un choix te paraît discutable, il l'est probablement — dis-le
plutôt que de le contourner en silence.
