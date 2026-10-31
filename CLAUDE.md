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

### Le code de retour dit vrai (depuis le 21 octobre 2026)

Pendant longtemps, des scénarios annonçaient `n ECHEC(S)` et sortaient quand
même avec 0 — ça a coûté plusieurs comptes rendus faux le 9 octobre 2026. Le
banc écoute maintenant ce que le scénario **dit** : une ligne `ECHEC(S)` fait
sortir avec 1. Le texte et le code de retour concordent ; si un jour ils se
contredisent, crois le texte et répare le banc.

Un scénario qui ne vaut que **chez un joueur** l'écrit dans ses dix premières
lignes : `-- banc: --sans-mj`. Le banc le lance alors sans le compagnon MJ.
Lancé avec, il échouait sans rien prouver et passait pour un rouge.

Pour tout passer en revue, en PowerShell :

```powershell
Get-ChildItem scenarios -Filter "lcm_test_*.lua" | ForEach-Object {
  $out = cmd /c ".\lcm.cmd `"scenarios\$($_.Name)`"" 2>&1 | Out-String
  if (($out -match "ECHEC\(S\)") -or ($out -match "ERREUR dans le scenario")) { $_.Name }
}
```

### L'état au 21 octobre 2026 : 126 verts, 0 rouge

Il était retombé à 34 rouges (sur 122). Presque tous étaient des attentes
périmées. Trois causes reviennent, à connaître :

* **Un commit qui réécrase des tests avec une vieille copie.** `6aae0fb` a
  remis sept scénarios (`dot`, `actions`, `buff`, `creation`,
  `creation_ecran`, `fiche_traits`, `objets`, plus la moitié de `vues`) dans
  leur état d'AVANT le correctif de leur auteur, supprimé cinq scénarios et
  retiré `__filtreChat` du banc. Avant de « rebaser » un rouge, regarde si une
  version plus récente du test existe dans l'historique et passe : c'était
  le cas pour tous ceux-là. (`gps_portee` est resté supprimé : le `.gps` de
  fond qu'il vérifiait n'existe plus.)
* **La distance en 3D.** Depuis le 16 octobre, un point (coffre, récolte, étal,
  sac) sans `z` est introuvable — c'est voulu. Un point d'essai doit porter
  son altitude, et ouvrir un coffre exige une mesure `.gps` récente : le banc
  en joue une avec `LCM.DeplacementForce.NoterGPS(...)`.
* **Le contenu qui vit**, encore : jeux d'équilibrage des états, limites
  d'anneaux, base d'état d'objet (10 → 40), ordre des points publiés.

Deux vrais bugs s'y cachaient : un point de récolte sans ressource renvoyait
le MJ sur la mauvaise page, et un coffre dont UN type d'outil avait été
supprimé disparaissait du jeu (« Cassier fermé. »).

### L'état au 12 octobre 2026 : 73 verts, 0 rouge

Le banc est **entièrement vert**, et c'est un état qu'on tient. Un rouge est
désormais un signal, pas du bruit de fond : si tu en vois un, c'est que
quelque chose vient de changer.

Il a fallu une passe entière pour y arriver (11–12 octobre 2026), et elle a
appris une chose qu'il faut garder :

> **Un test ne se pose jamais sur du contenu qui vit.**

Les vingt-trois rouges ne venaient presque jamais d'un bug. Ils venaient de
scénarios appuyés sur le contenu de la campagne, qui bouge à chaque séance :

* **Une race réelle.** Les tests de formules choisissaient « humain ». Son
  équilibrage lui a donné +3 à toutes les statistiques, et les PV, le poids,
  les sauts et le déplacement ont bougé sans qu'une ligne de formule change.
  → Ils déclarent maintenant une race **témoin**, sans aucun bonus
  (`LCM.Brouillons.Set("races", { id = "temoin", … })`).
* **Un barème de forge réel.** Depuis que le barème **bloque** (3 octobre), un
  trait ou un objet d'essai sans `forge` est refusé — et le refus passait
  inaperçu : l'entrée n'existait pas, donc aucun bonus, donc une cascade
  d'échecs sans rapport. → Chaque scénario déclare son **jeu d'équilibrage
  témoin**, large, au lieu de s'accrocher à ceux de la campagne. Et quand il
  raconte une catégorie qui part *sans* jeu, il écarte ceux de la campagne de
  sa propre mémoire (`LCM.Forge.Retirer`).
* **Des comptes de catalogue.** « 24 catégories », « 9 traits », « 2 PNJ ».
  → On vérifie que l'entrée connue est là, ou on compare à ce que le
  compendium déclare, plutôt que d'écrire un nombre qui se périme.
* **Un personnage à l'équilibrage périmé.** `VERSION_CREATION` a bougé, et la
  création imposait un rééquilibrage dès qu'on l'ouvrait.
  → `LCM.Creation.MarquerAJour(moi)` en tête de scénario.

Le reste était de vraies évolutions voulues, rebasées **avec leur raison
écrite dans le test** : barème des métiers (7 rangs → 30), valeurs d'armure,
budget de mécaniques, jauge d'armure qui compte désormais la durabilité, deux
emplacements d'arme, doublons d'objets autorisés, volet d'artwork qui ne se
referme plus en changeant d'onglet.

Et **trois vrais bugs** s'y cachaient, tous découverts en réparant :

1. Le bandeau de combat montrait les PA et PF du joueur, pas du PNJ incarné.
2. « Nouvelle entrée » sur une famille dosée par la Forge ouvrait l'ancien
   panneau à champs, qui n'a pas de champ « Forge » : on remplissait une
   entrée que l'enregistrement refusait ensuite, sans issue.
3. Un contenu publié recouvert par un brouillon avait disparu de l'atelier, et
   le brouillon ne disait plus qu'il « remplace le publié » — on perdait le
   rappel de reporter la correction dans le fichier.

C'est la raison d'être du banc : ces trois-là ne se voyaient pas en jeu.

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

**Les lieux : Crossings** (31 octobre 2026). L'ancien outil Lieux (seuils,
boussole, bannières maison) est **remplacé** par le module **Crossings**
d'Omega Hub, de la même main, repris en entier : pays › régions › lieux ›
passages (droit ou périmètre), bannières à thèmes et leur atelier, carte des
régions sur la touche M, Connaissances, auras imposées, sort Arcanum par
lieu. Sa documentation fonctionnelle est celle d'Omega (`README.md` du module
ZoneGate) ; ici, seulement ce que l'adaptation a changé.

* **Où** : le moteur dans `Core/Crossings.lua`, la bannière, la carte et le
  widget Arcanum dans `UI/Crossings/` (addon joueur) ; le panneau, l'atelier
  des bannières, le tracé et les Connaissances dans
  `LesContesMalveillants_MJ/Crossings/`. Il s'ouvre par la branche **Lieux**
  du radial ; pas de commande slash.
* **Tous les noms globaux sont renommés** (`LCMCrossings`, sauvegardes
  `LCM_Crossings` / `LCM_CrossingsChar`, préfixe et canal `LCMCrossings`) :
  Omega_Hub est installé dans le même dossier AddOns, et deux modules sur la
  même table ou le même préfixe s'écraseraient. Le banc le vérifie.
* **La position** passe par `ZG:GetPlayerPose`, seul point de lecture :
  `UnitPosition`, sinon la position serveur de `DeplacementForce` (Epsilon ou
  `.gps`), dans le **même repère** (X serveur au nord, Y à l'ouest, la carte
  serveur en guise d'instance). La position « carte » n'est pas utilisée :
  elle ne compte pas dans la même unité. Sur une carte d'instance, le cap
  (`GetPlayerFacing`) peut manquer : le tracé tourne alors mal, la détection
  non.
* **Une commande serveur** (aura d'un lieu) passe par
  `DeplacementForce.Commande`, comme `.gps`.
* **OnUpdate plutôt que C_Timer** : le battement et les rappels différés
  (`ZG.Apres`) tournent sur un cadre, que le banc sait faire avancer.
* **L'interface est celle de LCM.** Les écrans gardent leur logique et leur
  mise en page, mais `UI/Crossings/Kit.lua` construit chaque widget avec le
  Kit (bouton, champ, case, liste) et `UI.Habiller` glisse chaque fenêtre
  dans une `UI.Fenetre` (cadre A'hell'Raz'kah, titre couronné, place
  retenue). Les menus déroulants, le curseur et les fonds Blizzard d'Omega
  ont été remplacés par ceux du Kit. Un widget Crossings qui manque se
  traduit dans ce fichier, jamais dans un écran.
* **On est reparti de zéro** : les lieux et thèmes de l'ancien outil
  (`LCM_DB`) ne sont pas convertis — ni effacés.
* Les 42 compositions et les polices de `ressources/bannieres` étaient déjà
  celles de Crossings, octet pour octet ; seules les musiques
  (`ressources/bannieres/musiques`, 1,2 Mo) et un son ont été ajoutés.

**Les cartes** (`Core/Cartes.lua`, `UI/Cartes.lua`, `MJ/CartesUI.lua`,
31 octobre 2026). Un objet du compendium (catégorie « Cartes », comme les
Livres) rattaché à une région Crossings : le MJ coche les lieux qu'elle
dévoile et pose des repères (une ressource, un vendeur, un coffre posés, ou
une épingle libre). La lire apprend les noms pour de bon ; la vue se rouvre
tant qu'on la possède. Le choix « objet du compendium » vient d'une étude de
100 situations de MJ : un objet se trouve déjà dans un coffre, au sol et par
échange. Une carte peut en **reprendre** une autre.

* La famille est **réservée au MJ** (comme `pnj`, `RESERVED_MJ` dans
  `lcm_db.py`, absente de `BasePublique.REGISTRES`) : un joueur ne reçoit une
  carte qu'en la trouvant, sa définition voyage avec l'objet. Une carte qui en
  reprend une autre part **aplatie**.
* Livres et cartes passent par **un seul aiguillage**, `LCM.Lisibles`
  (`Definition`, `Importer`) : coffres, récolte, échange. Un troisième objet
  lisible s'y ajoute, pas dans chaque module.
* Les repères sont dans le repère de Crossings : un point posé (x, y de
  `UnitPosition`) y entre **axes échangés** ; un point posé par la carte du
  jeu (source « carte ») est refusé.

**Les panneaux d'affichage** (`Core/Affichages.lua`, `UI/Affichage.lua`,
`MJ/Affichages.lua`, `MJ/AffichagesUI.lua`, `Data/Affichages.lua`). Un point
de nature « affichage » : un support et des affiches (titre, texte, image),
posé au GPS ; devant, « Lire » ouvre le panneau. Le circuit des vendeurs sans
stock ni arbitre. Les **supports** sont de la structure (`Data/Affichages.lua`,
format des textures documenté en tête) ; seul le support provisoire, dessiné
par l'addon, existe tant que les textures ne sont pas fournies.

**Un brouillon recouvre une entrée publiée** (`MJ/Brouillons.lua`). Modifier du
contenu publié tenait le temps de la séance puis disparaissait au `/reload` :
la boucle de chargement n'avait pas ce cas. Elle l'a maintenant, et garde une
copie de l'original pour que supprimer le brouillon la rende au lieu de
l'effacer.

## Les points posés dans la base commune (21 octobre 2026)

Le **modèle** d'un coffre, d'un filon ou d'un vendeur est du contenu (famille
`points`). Ce qui en est **posé** — où, avec quoi dedans, le stock, qui
l'arbitre — vit dans la famille `poses` (`LesContesMalveillants_MJ/Poses.lua`),
réservée au MJ : jamais dans l'addon joueur, où l'on lirait l'emplacement des
coffres cachés.

* **Un arbitre par point posé**, pas par modèle (`Coffres.Auteur`,
  `Recolte.Auteur`, `Marchands.Auteur`). Tenu par le modèle, l'annonce d'un MJ
  effaçait les points que l'autre avait posés du même modèle.
* **Même file d'envoi que le contenu** : chaque changement passe par
  `Poses.Noter` (dans `Partager` pour les coffres, `Rafraichir` pour les
  autres), un retrait par `Poses.Supprimer`, une garde perdue par
  `Poses.Lacher` (sa ligne est à l'autre maintenant).
* **La base est en retard sur la séance** : elle sert de sauvegarde et de point
  de départ. Au chargement, un MJ récupère SES points qui manquent ; les coffres
  d'un autre passent par `RecevoirCopie`, comme une copie reçue en séance. Les
  filons et vendeurs d'un autre MJ sont connus mais pas encore servis en son
  absence : la garde n'existe que pour les coffres.
* Côté service, deux versions d'un même point **ne bloquent pas** la
  synchronisation : la plus récente l'emporte (`pose_plus_recente`, même règle
  que l'addon), une suppression toujours.

**Le service de synchro de référence est `Outils/`** (avec
`database/lcm_db.py`). `LesContesMalveillants_MJ/Sync/` n'en est qu'une copie
déployée : le travail sur le quota avait été fait dans la copie, puis perdu du
dépôt quand elle a été retirée. Après un changement, recopier les quatre
fichiers dans `Sync/` (sans toucher à ses fichiers d'état) et relancer le
processus `pythonw … gsheet_auto.py watch`.

**Le code de `Sync/` est de nouveau suivi dans le dépôt** (21 octobre 2026) :
c'est par lui que le binôme reçoit le service — `recuperer.ps1` copie tout
fichier du dossier MJ du dépôt, et sans ces fichiers sa copie restait
ancienne. Seuls le code et les installeurs y vont, jamais `entries/` ni les
états (le `.gitignore` les écarte). Il faut donc les recopier **aussi** dans
`LesContesMalveillants_MJ/Sync/` du dépôt, pas seulement dans AddOns. Après
récupération, chacun relance son service.

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
