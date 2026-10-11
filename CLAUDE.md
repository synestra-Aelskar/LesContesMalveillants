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

### L'état au 11 octobre 2026 : 49 verts, 23 rouges

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

### Un plafond qui n'était pas une règle, et un plafond en double

Le dossier Outils du menu radial était « plein à huit, le maximum qu'un
éventail sait dessiner ». Ce n'était pas une règle de dessin : c'était le
nombre de **bandeaux** présents dans `ressources/radial`
(`grimoire-fan-1..8`), l'arc de cuir posé derrière la rangée de boutons. Les
huit sont le même objet à huit longueurs — même rayon intérieur (~308) et
extérieur (~470), et un empan qui croît d'un pas constant de 20,57°, qui est
exactement l'angle d'une branche (`math.pi / 8.75` dans `UI/Radial.lua`).

La neuvième longueur se **fabrique** donc : on étire angulairement la huitième
en gardant ses deux embouts dorés au 1:1, seul le cuir du milieu s'allonge.
Rien n'est repeint. La méthode a été vérifiée avant de servir, en refabriquant
le bandeau de **huit** à partir de celui de **sept** : 97,6 % de recouvrement
avec le vrai, écart médian 4/255. Si une dixième branche devient nécessaire,
c'est le même geste.

Au passage, `lcm_test_radial_competences` a trouvé ce que relever le plafond
n'avait pas suivi : les Compétences se plafonnaient **une seconde fois**, en
dur (`if #out >= 8`). Le test comparait au constant et non à huit, et c'est
pour cela qu'il l'a vu. Les deux plafonds lisent maintenant
`Radial.MAX_ENTREES`, y compris la vérification au chargement de
`UI/Menu.lua`.

### Les mécaniques de défense

Sept, dans `Equilibrage.defenses` (`Core/Defenses.lua`). On n'y investit pas
pour agir mais pour **encaisser**, sur le même budget que les mécaniques de
compétence et avec le même plafond.

Deux sortes, et il ne faut pas les confondre. **Réduction** : un pourcentage
retiré aux dégâts. Une seule la porte, la Défense (3 %/point contre attaque
simple, perce-armure, brise-armure). **Rand** : un bonus au jet de défense
(+0,5/point) — Résilience mentale, Esprit libre, Courage, Insensible, Stable,
Agilité, chacune contre les mécaniques que `contre` nomme.

Une mécanique d'attaque sans défense dédiée n'en a pas, et c'est voulu : on ne
se défend pas contre un soin.

**Deux garde-fous ajoutés** : la réduction plafonne à 90 %, et ce qui reste est
arrondi au supérieur avec un minimum de 1 — une réduction ne doit pas effacer
une attaque qui a touché.

### Un seul point de branchement, de chaque côté

C'est ce qui fait tenir l'ensemble, et c'est à respecter si on ajoute une
règle du même genre.

**En réception**, tout passe par `Actions.JetFormule` : les défenses et les
expertises de parade s'y ajoutent, et nulle part ailleurs. Le bonus ne vaut
que dans une réception — `ctx.paquet` le dit, et il n'est posé que par
`Actions.Resoudre`. Un jet d'attaque ne profite donc jamais d'une défense.
Pour les parades, `JetFormuleBrut` rend en plus **le champ sur lequel le jet a
porté** : l'information était là, elle se perdait.

Les **dégâts** reçus, eux, se réduisent dans `Pas.apply`, seul endroit où un
dégât entre avant d'être réparti. Et la **part obligatoire** du perce-armure
s'allège dans `Actions.PerceMinimum`.

**En émission**, tout passe par `Pas.declare` : la Puissance y gonfle `Total
Normal` et `Total Critique`, le supplément de Projection s'ajoute au jet.

### Ce que les expertises apportent

`Equilibrage.effetsExpertises` (`Core/Expertises.lua`) — à ne pas confondre
avec `apportsExpertises`, qui dit ce qui **nourrit** une expertise. Ici c'est
l'inverse : ce qu'elle change ailleurs. On compte sur la valeur **totale**
(investi + apports + bonus portés).

Les Résistances **allègent la part obligatoire** de 2 %/point : elles ne
retirent aucun dégât, elles rendent leur placement plus libre. C'est le sens
de la règle, et le piège serait de les transformer en réduction.

**Deux demandes étaient déjà satisfaites** et n'ont rien coûté : l'Endurance
alimente la fatigue depuis le départ (+1/point total, dans la formule de la
jauge), et Course/Nage apportent déjà leur distance — mais **+1 yard par point
investi**, pas +0,5 sur le total. À trancher avant d'y toucher : changer le
taux diviserait le déplacement de tous les personnages existants.

### Les races remboursent en entier

Règle générale de la forge : une statistique passée **sous sa base** ne rend
que la **moitié** de son coût au pool. Sinon descendre une stat financerait
entièrement la montée d'une autre, et le pool ne bornerait plus rien.

**Les races font exception, et elles seules** (11 octobre 2026) : une race se
définit autant par ses faiblesses que par ses forces, et ne rembourser que la
moitié d'une faiblesse revient à décourager d'en donner. Baisser une stat de 1
dont le point coûte 1 rend donc 1.

Le taux n'est pas écrit en dur : `forge.remboursement` (0,5) et
`forge.remboursementParCategorie` (`races = 1`) sont des vecteurs
d'équilibrage, réglables en séance comme le reste. Le plafond du pool, lui, ne
bouge pas : rembourser en entier ne permet pas de le dépasser.

### Le fond d'une fenêtre passe SOUS ses bordures

L'habillage A'hell'Raz'kah est ancré sur l'**intérieur** du cadre : toute la
bordure dorée est dessinée **en dehors** du rectangle de la fenêtre — 34 unités
à gauche et à droite, 29 en bas pour le thème léger. Le fond, lui, couvrait le
rectangle et pas un pixel de plus. Entre le noir et l'or : rien. Sur un fond
sombre ça ne se voit pas ; sur un ciel clair, la bordure a l'air faite de
lumière (constaté le 11 octobre 2026).

Le bord du **haut** avait déjà été rattrapé, avec un commentaire qui décrit
exactement ce symptôme — mais les trois autres n'avaient jamais eu le même
traitement.

La limite à ne pas franchir : pousser le noir jusqu'au bout de la tranche
ferait **dépasser un bandeau par-dessus la bordure**, le piège déjà payé en
haut. Le fond s'arrête donc là où la bande devient franchement opaque, et
cette fraction est **mesurée sur l'alpha de l'atlas**, pas devinée :
`Outils/mesurer_bandes.py` la relève pour les deux thèmes, et elle vit dans
`bandeOpaque`, à côté de `railOpaque`. Si l'atlas change, on remesure.

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

**Les lieux** (`Core/Lieux.lua`, `UI/Banniere.lua`, `MJ/Lieux.lua`, branche
**Lieux** du dossier Outils du menu radial, ou `/lcm atelier-lieux`). Nommer un
endroit, et le dire à celui qui y entre. Un **lieu** porte des **seuils** ; franchir un
seuil affiche une bannière avec le nom du lieu et celui du seuil.

L'idée vient du module **Zone Gate** d'Omega Hub (Akriaxx). Trois écarts, et
chacun répare quelque chose :

* **une porte se pose avec deux bornes**, pas avec l'orientation du personnage.
  Zone Gate capture `GetPlayerFacing` et en déduit la normale de la porte ;
  `UnitPosition` rend **y avant x**, et une normale calculée sur des axes
  inversés se retourne sans prévenir. Deux bornes donnent en plus au passage sa
  largeur réelle au lieu d'un nombre à deviner. Tant que la seconde manque, le
  seuil est **inerte** et le dit ;
* **la position passe par `LCM.DeplacementForce.Position`**, rendue publique
  pour l'occasion. Zone Gate appelle `UnitPosition` directement — qui ne répond
  pas sur une carte d'instance, et nos cartes de campagne en sont. Il y a trois
  sources (le monde, la carte, `.gps`) et elles **ne comptent pas dans la même
  unité** : un seuil retient celle qui l'a capturé et ne se mesure qu'avec elle.
  Mélanger des yards du monde et des yards de carte ferait franchir une porte
  sans bouger ;
* **le nom se découvre en entrant**, par défaut. Zone Gate masque tout jusqu'à
  ce que l'auteur débloque le nom joueur par joueur : utile pour un secret, pas
  pour une région ordinaire. Le MJ coupe la découverte automatique sur ce qu'il
  veut tenir caché, et révèle à la main (`Reveler`).

Trois formes de seuil : **porte** (deux bornes, plus un débord toléré au-delà),
**cercle** (centre et rayon) et **région** (contour de 3 à 20 points, qu'il faut
*fermer*). Une bande morte de 1,5 m autour de la frontière évite qu'un
personnage posté sur le seuil fasse clignoter la bannière. L'état de chaque
seuil ne va **pas** en sauvegarde : au `/reload` on réarme, et le premier
battement note le côté sans rien annoncer — se reconnecter dans un lieu ne doit
pas faire croire qu'on vient d'y entrer.

L'atelier a un **radar** : le joueur au centre, nord en haut, et le seuil
dessiné à l'échelle — le segment entre les deux bornes d'une porte avec ses
côtés nommés ENTRÉE et RETOUR, le disque d'un cercle, le contour d'une région
(ouvert tant qu'il n'est pas validé). Les boutons de pose sont **à côté** : on
pose une frontière en marchant, il faut voir où l'on est au moment où l'on
clique. L'échelle se choisit seule, parmi des paliers, pour que le seuil tienne
toujours dedans.

**Le nord se mesure, il ne se suppose pas** (`Lieux.Boussole`,
`Lieux.Calibrer`, `Lieux.ResoudreBoussole`). Les trois sources de position ne
nomment pas leurs axes pareil, et jusqu'à ce radar personne n'avait eu besoin
de le savoir : une distance est la même quel que soit le sens des axes. Une
carte, non — et un radar en miroir se lit très bien, on ne s'en aperçoit qu'en
posant une porte à l'envers.

La première version portait une table de conventions, déduite. Elle a été
remplacée par une **mesure**, parce que le client sait répondre :
`C_Map.GetPlayerMapPosition` rend une fraction du rectangle de carte, et une
carte est au nord par construction — sa fraction *x* va vers l'est, sa *y*
descend vers le sud. Ça, ce n'est pas une convention d'axes, c'est la
définition d'une image de carte.

Il suffit donc de regarder marcher le MJ, ce qu'il fait de toute façon pour
poser ses bornes. Deux déplacements non parallèles donnent la matrice qui passe
de la source à la carte ; son inverse, appliquée à l'est et au nord de la
carte, donne l'est et le nord **dans la source**. On ne se sert que des
directions, jamais de l'échelle : la mesure marche donc aussi sur une carte qui
ne déclare pas sa taille — c'est-à-dire sur les cartes de campagne. Le résultat
est gardé par carte et par source, en sauvegarde.

**La carte n'est pas toujours là**, et c'est ce qui a mordu : sur une carte qui
ne répond pas, la mesure n'aboutissait jamais, le radar restait sur « N ? » et
la convention gardait les commandes — fausse d'un quart de tour, constaté en
jeu. Il y a donc un **second chemin, sans la carte** : marcher droit devant,
c'est avancer vers son cap. Deux trajets droits de caps différents donnent
`theta = A·phi + C`, et C **est** le nord (`ResoudreBoussoleParMarche`). La
carte reste préférée quand elle répond — elle tranche le sens sans rien
supposer — et la marche prend le relais sinon.

Et le MJ peut **redresser à la main** : « ¼ de tour » et « Miroir » dans
l'atelier atteignent les huit orientations possibles. Une boussole posée ainsi
se sait telle : l'écran dit « nord réglé à la main », jamais « mesuré ».

Deux garde-fous : des déplacements trop parallèles sont refusés, et un est et
un nord qui ne sortent pas perpendiculaires le sont aussi — c'est le signe que
les deux relevés ne viennent pas du même repère. Mieux vaut jeter la mesure que
poser un nord de travers.

La table `Lieux.CONVENTION` reste, en **dernier recours**, pour le cas où la
carte ne répond pas du tout ; l'atelier affiche alors « N ? » et « nord par
convention — marche un peu pour le mesurer », pour qu'un nord supposé ne passe
jamais pour un nord su. Le banc (`lcm_test_boussole`) vérifie le solveur sur
des transformations connues, confirme que la convention de « monde » disait
vrai, et mesure une carte tournée que la convention aurait ratée.

Ce qui n'a **pas** été repris de Zone Gate : l'atelier de bannières (42
modèles, 18 polices, musiques, ornements). Une bannière se lit en deux
secondes. Le seul réglage d'apparence est la **couleur du lieu**, parce que
c'est le seul qui raconte quelque chose.

**Limite connue** : les lieux vivent dans `LCM_DB` et voyagent par le réseau
(un message par lieu, clés courtes, points pliés en une chaîne). Ils ne passent
**pas encore** par la base commune — deux MJ qui en créent chacun de leur côté
ne les fusionnent pas, ils se les diffusent. Un lieu reçu n'écrase jamais un
lieu dont on est l'auteur.

**Les bannières** (`Core/Bannieres.lua`, `UI/Banniere.lua`, `MJ/Bannieres.lua`,
`/lcm atelier-bannieres` ou le bouton « Atelier… » depuis un lieu). De quoi a
l'air le nom d'un lieu quand on y entre : composition de fond, police,
couleurs, filets, cadre, mouvement, place à l'écran, durées, sons.

**Les images et les polices sont l'ouvrage d'Akriaxx**, reprises de son module
Zone Gate avec son accord (10 octobre 2026) : 42 compositions et 15 polices
(SIL Open Font License, les `OFL-*.txt` sont à côté des fichiers), dans
`ressources/bannieres`. **C'est 47 Mo dans l'addon joueur** — de loin le plus
gros poste de la distribution. À savoir avant d'en ajouter.

Le rendu est porté de son `UI_Banner.lua`, avec deux simplifications : son
groupe d'animation est abandonné (il était créé, configuré… et jamais joué —
c'est `Chercher`, appelé par le OnUpdate, qui fait réellement l'alpha et les
mouvements), et un franchissement pendant une bannière la relance au lieu de
faire la queue, comme chez lui.

Deux choses à savoir si on y touche :

* **le formulaire de l'atelier est ENGENDRÉ** par `Bannieres.CHAMPS`. Ajouter
  un réglage, c'est ajouter une ligne à cette table : le formulaire, la
  validation et le transport réseau la lisent tous les trois. Vingt-quatre
  contrôles posés à la main auraient divergé au premier ajout ;
* **pas de galerie de vignettes**, contrairement à chez lui. Une composition
  pèse un mégaoctet : les afficher ensemble, c'est 42 Mo de textures pour en
  choisir une. La liste déroulante les range par famille et l'aperçu montre
  celle qu'on vient de prendre — une image à la fois.

Un thème se pose sur un **lieu** (tous ses seuils en héritent) ou sur un
**seuil** en particulier, qui l'emporte. Il voyage avec le lieu sur le réseau,
sinon le MJ verrait sa bannière et ses joueurs du texte nu.

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
