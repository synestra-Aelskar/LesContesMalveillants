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
`n ECHEC(S)`. Copie n'importe lequel des douze de `Banc/scenarios/` pour démarrer.

**Les douze scénarios doivent être au vert avant de publier.** Si tu en casses
un, c'est soit un vrai bug, soit une attente du test devenue fausse — dans le
second cas, corrige le test *et dis-le*, ne le contourne pas.

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
