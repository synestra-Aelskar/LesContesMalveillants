# Base LCM dans un classeur Google Sheets

Un seul classeur sert de base commune. Le script cree **23 feuilles** : une pour
chacune des 18 familles de contenu (`Objets`, `Traits`, `Races`, `Etats`,
`Apprentissages`, `Sacs`, `Ressources`, `Devises`, `Informations`, `Listes`,
`Connaissances`, `Resolutions`, `Calculateurs`, `PNJ`, `Jeux`, `Points`, `Tentes`,
`Accessoires camping`), puis `Reglages`, `Comptes`, `Fiches`, `Etat MJ` et
`Archives`. La liste exacte est dans `Outils/feuilles_lcm.json`.

Le classeur source reste prive aux deux MJ. Les joueurs installent uniquement
`LesContesMalveillants` : ses definitions publiques de depart sont incluses, et
il demande les mises a jour aux MJ connectes par le canal de presence de WoW.
Les nouvelles definitions recues sont gardees dans leurs SavedVariables pour
les connexions suivantes. Une mise a jour ne peut arriver que lorsqu'un MJ
ayant le compagnon et la synchronisation Sheets est connecte. La colonne `MJ`
controle la distribution : `FALSE` peut partir aux joueurs, `TRUE` reste dans
le compagnon MJ. La cle Google ne doit jamais etre copiee dans l'addon joueur.
`MJ` est distinct de `mjSeulement`, qui masque seulement l'affichage en jeu.

## Preparation

1. Un MJ cree le classeur vide et le partage en edition avec l'autre MJ.
2. Activer l'API Google Sheets dans Google Cloud, creer un compte de service et
   partager ce classeur en edition avec son adresse courriel. Garder la cle JSON
   hors du depot. Un MJ reste proprietaire du classeur.
3. Installer les dependances : `python -m pip install google-auth requests watchdog psutil`.
4. Controler la repartition : `python Outils/gsheet_base.py apercu`.

L'identifiant du classeur se trouve dans son URL entre `/d/` et `/edit`.
Le premier lancement cree et formate les feuilles, puis importe le contenu
local :

```powershell
python Outils/gsheet_base.py initialiser --sheet-id IDENTIFIANT --credentials C:\chemin\prive\service-account.json
```

Ensuite, chaque MJ lance `sync` avant et apres ses modifications :

```powershell
python Outils/gsheet_base.py sync --sheet-id IDENTIFIANT --credentials C:\chemin\prive\service-account.json
```

On peut limiter la passe a une famille avec `--feuille traits`, `objets`, `jeux`,
etc. Le script detecte les modifications concurrentes avant d'ecrire dans la
feuille concernee. Chaque ordinateur garde son propre etat local non partage
dans `database/.gsheet_state_*.json`.

Dans les feuilles de contenu, `Nom`, `Description` et `MJ` sont modifiables
directement. Les autres champs sont dans `Definition Lua`, une table Lua qui doit
garder le meme `id`. Pour supprimer une entree, mettre `SUPPRIME` dans `Statut` ;
supprimer une ligne entiere est traite comme un conflit. Les familles `pnj`,
`jeux`, `points` et les resolutions de categorie `mj` restent toujours MJ.

## Donnees sauvegardees par WoW

Faire `/reload` ou fermer WoW avant la sauvegarde :

```powershell
python Outils/gsheet_base.py sauvegarder --sheet-id IDENTIFIANT --credentials C:\chemin\prive\service-account.json --retail C:\chemin\WoW\_retail_
```

Le script archive les fichiers LCM de `WTF/Account`, y compris les fiches par
personnage et les `.bak`. Il cree d'abord un ZIP local dans `Sauvegardes_LCM`,
puis ajoute des fragments compresses dans `Archives`. Il remplit aussi les
feuilles `Comptes`, `Fiches` et `Etat MJ` avec les valeurs lisibles des dernieres
`SavedVariables` ; une erreur de lecture est affichee dans la feuille concernee,
et le fichier brut reste dans `Archives`. `Reglages` reflete les fichiers de
reglages de la base locale.

Un manifeste et des empreintes SHA256 permettent de verifier qu'une
restauration est complete. Cette archive ne synchronise pas automatiquement
les fiches entre PC.

Pour restaurer dans un dossier neuf, prendre l'identifiant d'instantane de la
premiere colonne d'`Archives` et lancer :

```powershell
python Outils/gsheet_base.py restaurer --sheet-id IDENTIFIANT --credentials C:\chemin\prive\service-account.json --instantane 20261014_190000_+0200 --destination C:\restauration-LCM
```

La restauration ne remplace jamais directement les fichiers de WoW.

## Synchronisation automatique sur chaque PC MJ

Le programme Python est embarque dans
`LesContesMalveillants_MJ/Sync/Outils/gsheet_auto.py`. Le dossier `Sync` est
prepare depuis le depot par `python Outils/packager_sync.py`, puis livre avec
le seul addon MJ. Il comprend une copie initiale de la base, sans cle Google,
sans sauvegardes WoW et sans etat local. Ne jamais le livrer aux joueurs.

Installer Python et les dependances sur chaque ordinateur MJ, garder la cle
Google hors des dossiers d'addon, puis installer la tache Windows depuis le
dossier de l'addon MJ :

Ne pas double-cliquer `gsheet_auto.py` : ce programme exige le mode (`watch`),
l'identifiant du classeur et le chemin de la cle. Apres avoir installe Python
et les dependances, lancer `Sync/Outils/installer_sync.cmd` depuis l'addon MJ ;
il demande ces deux informations puis installe et demarre la tache Windows.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  E:\Games\Epsilon\_retail_\Interface\AddOns\LesContesMalveillants_MJ\Sync\Outils\installer_sync.ps1 `
  -SheetId IDENTIFIANT -Credentials C:\chemin\prive\service-account.json
```

La tache `LCM Google Sheets Sync` pointe vers ce programme dans l'addon MJ et
installe une veille legere a l'ouverture de session Windows. WoW ne peut pas
lancer Python lui-meme ; la connexion au Sheet et la mise a jour des addons
demarrent des que `Wow.exe` s'ouvre, pendant l'ecran de connexion. Elle ecoute ensuite
les ecritures des SavedVariables MJ sans ouvrir de terminal. Apres un
`/reload` ou une deconnexion, elle archive les fichiers WoW, importe seulement
les brouillons modifies depuis le dernier controle, les envoie dans le Sheet
et reconstruit les deux fichiers `Atelier.lua` dans les addons installes.
Tant que WoW reste ouvert, elle relit le Sheet chaque minute pour recuperer les
modifications de l'autre MJ. Si WoW est deja en jeu, un `/reload` charge les
nouveaux fichiers. Le journal se trouve dans `Sauvegardes_LCM/synchro.log`.

Le premier lancement enregistre les brouillons deja presents comme point de
depart : leurs anciennes versions divergentes ne sont pas republiees sans
controle. Une modification ulterieure est detectee. Si les deux MJ modifient
la meme entree depuis le meme point de depart, la synchronisation s'arrete sur
un conflit pour cette entree et conserve les fichiers WoW, la copie ZIP et les
fichiers locaux. Les brouillons deja publies sont retires des SavedVariables
uniquement lorsque WoW est ferme, apres une nouvelle archive. Les autres
donnees de compte et de personnage restent dans leurs fichiers WoW et dans
`Archives` : elles ne sont pas remplacees par les valeurs de l'autre MJ.

Pour verifier immediatement sans attendre la tache :

```powershell
python Outils/gsheet_auto.py once --sheet-id IDENTIFIANT `
  --credentials C:\chemin\prive\service-account.json `
  --retail E:\Games\Epsilon\_retail_
```
