# Publication des Contes Malveillants.
#
#   .\publier.ps1              -> publie l'addon ET le compagnon MJ
#   .\publier.ps1 -Apercu      -> prepare tout sans rien pousser
#   .\publier.ps1 -Message "…" -> impose le message de commit
#
# Le compagnon MJ part dans le MEME depot, dans son propre dossier : il n'y a
# aucun secret dans son code, seulement du contenu. Ce qui protege les joueurs,
# c'est que l'outil de mise a jour « joueurs » ne l'installe pas.
param(
    [string]$Message = '',
    [switch]$Apercu,
    [switch]$Forcer
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lcm.config.ps1')

function Etape($t) { Write-Host ''; Write-Host ('=== ' + $t) -ForegroundColor Cyan }
function Info($t)  { Write-Host ('    ' + $t) -ForegroundColor Gray }
function Ok($t)    { Write-Host ('    ' + $t) -ForegroundColor Green }
function Alerte($t){ Write-Host ('    ' + $t) -ForegroundColor Yellow }
function Pause-Fin($t) { try { Read-Host $t | Out-Null } catch { } }
function Stop-Erreur($t) {
    Write-Host ''; Write-Host ('ERREUR : ' + $t) -ForegroundColor Red; Write-Host ''
    Pause-Fin 'Appuyez sur Entree pour fermer'; exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-Erreur "git est introuvable. Installe Git pour Windows puis relance."
}

# Version lue dans le .toc de l'addon : une seule source de verite.
function Get-TocVersion($tocPath) {
    if (-not (Test-Path -LiteralPath $tocPath)) { return '0.0.0' }
    foreach ($ligne in (Get-Content -LiteralPath $tocPath -Encoding UTF8)) {
        if ($ligne -match '^\s*##\s*Version:\s*(.+)$') { return $Matches[1].Trim() }
    }
    return '0.0.0'
}

# Copie un dossier d'addon : uniquement ce que WoW charge (fichiers du .toc,
# le .toc, version.txt) plus les textures. Les notes de travail restent ici.
function Copy-Addon($source, $destination) {
    if (-not (Test-Path -LiteralPath $source)) { Stop-Erreur "dossier introuvable : $source" }
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    $toc = Get-ChildItem -LiteralPath $source -Filter '*.toc' | Select-Object -First 1
    if (-not $toc) { Stop-Erreur "aucun .toc dans $source" }
    Copy-Item -LiteralPath $toc.FullName -Destination $destination

    $manquants = @()
    $copies = 0
    foreach ($ligne in (Get-Content -LiteralPath $toc.FullName -Encoding UTF8)) {
        $l = ($ligne -replace "^\xEF\xBB\xBF", '').Trim()
        if ($l -eq '' -or $l.StartsWith('#')) { continue }
        $chemin = Join-Path $source $l
        if (-not (Test-Path -LiteralPath $chemin)) { $manquants += $l; continue }
        $cible = Join-Path $destination $l
        $dossier = Split-Path $cible -Parent
        if (-not (Test-Path -LiteralPath $dossier)) { New-Item -ItemType Directory -Force -Path $dossier | Out-Null }
        Copy-Item -LiteralPath $chemin -Destination $cible -Force
        $copies++
    }
    if ($manquants.Count -gt 0) {
        Stop-Erreur ("le .toc liste des fichiers absents : " + ($manquants -join ', '))
    }

    # Bindings.xml n'est jamais liste dans un .toc : WoW le charge tout seul a la
    # racine de l'addon. Sans cette ligne, les raccourcis clavier ne partaient
    # pas chez les joueurs.
    foreach ($extra in @('version.txt', 'Bindings.xml')) {
        $chemin = Join-Path $source $extra
        if (Test-Path -LiteralPath $chemin) { Copy-Item -LiteralPath $chemin -Destination $destination -Force }
    }
    # Les textures ne sont pas listees dans le .toc : elles sont chargees par leur
    # chemin depuis le Lua. Sans cette copie, l'addon arrive sans son habillage
    # et WoW affiche des carres verts a la place.
    foreach ($dossier in @('Media', 'ressources')) {
        $chemin = Join-Path $source $dossier
        if (-not (Test-Path -LiteralPath $chemin)) { continue }
        $sortie = & robocopy $chemin (Join-Path $destination $dossier) *.tga *.blp *.ttf /S /NFL /NDL /NJH /NJS /NP
        if ($LASTEXITCODE -ge 8) { Write-Host ($sortie -join [Environment]::NewLine); Stop-Erreur ('copie de ' + $dossier + ' impossible.') }
        $global:LASTEXITCODE = 0
        $nombre = (Get-ChildItem -LiteralPath (Join-Path $destination $dossier) -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        Ok ((Split-Path $source -Leaf) + " : $nombre fichier(s) dans $dossier.")
    }
    Ok ((Split-Path $source -Leaf) + " : $copies fichier(s) du .toc.")
}

Etape 'Preparation'
$clone = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.publication'))
if (-not (Test-Path -LiteralPath (Join-Path $clone '.git'))) {
    New-Item -ItemType Directory -Force -Path $clone | Out-Null
    & git -C $clone init -q
    & git -C $clone remote add origin $LcmRepo
} else {
    & git -C $clone remote set-url origin $LcmRepo
}
# La base est maintenant modifiee directement dans le clone Git. Un reset la
# detruirait : on refuse donc de publier tant que ces changements n'ont pas ete
# envoyes avec « Base - Envoyer.bat ».
$baseLocale = & git -C $clone status --porcelain -- database 2>$null
if ($baseLocale) {
    Stop-Erreur 'La base commune contient des changements non envoyes. Lance d''abord « Base - Envoyer.bat ».'
}
& git -C $clone fetch origin --prune --quiet
if (& git -C $clone ls-remote --heads origin $LcmBranch) {
    & git -C $clone checkout -B $LcmBranch ('origin/' + $LcmBranch) --quiet
    & git -C $clone reset --hard ('origin/' + $LcmBranch) --quiet
} else {
    & git -C $clone checkout -B $LcmBranch --quiet
}
Info ('clone de travail : ' + $clone)

# ----- Garde-fou a deux : ne pas ecraser ce qu'on n'a pas recupere ----------
# La copie efface le dossier d'addon du clone et le refait a partir de CETTE
# machine. Si quelqu'un d'autre a publie entre-temps et qu'on ne l'a pas
# recupere, son travail disparait en un commit, sans conflit et sans bruit :
# git voit simplement des fichiers « modifies ».
#
# On retient donc le commit que cette machine a publie en dernier. Si le depot
# a avance depuis, on s'arrete, et « Recuperer.bat » remet le depot dans le
# dossier d'addon avant de republier.
$traceBase = Join-Path $PSScriptRoot '.publie\base.sha'
$distant = (& git -C $clone rev-parse ('origin/' + $LcmBranch) 2>$null)
if ($distant) { $distant = $distant.Trim() }
if ((Test-Path -LiteralPath $traceBase) -and $distant) {
    $connu = (Get-Content -LiteralPath $traceBase -Raw).Trim()
    if ($connu -and $connu -ne $distant) {
        $nouveaux = & git -C $clone log --format='%h %an : %s' ($connu + '..' + $distant)
        if ($nouveaux -and -not $Forcer) {
            Write-Host ''
            Alerte 'Le depot a avance depuis ta derniere publication :'
            foreach ($l in $nouveaux) { Info ('  ' + $l) }
            Write-Host ''
            Stop-Erreur ("publier maintenant ECRASERAIT ce travail. Lance d'abord " +
                "« Recuperer.bat » (il remet le depot dans ton dossier d'addon), " +
                "verifie que tes modifications y sont toujours, puis republie. " +
                "Si tu sais ce que tu fais : publier.ps1 -Forcer")
        }
    }
}

# Les brouillons crees depuis le dernier /reload entrent dans la base APRES le
# garde-fou distant, mais avant la copie des addons. Le build actualise
# Atelier.lua ; Copy-Addon prendra donc les fichiers reconstruits dans ce commit.
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'base.ps1')) {
    & (Join-Path $PSScriptRoot 'base.ps1') -Mode importer
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'import de la base commune impossible.' }
}

# Les empreintes de « ce qui est publie » ne s'ecrivent qu'APRES l'envoi : les
# ecrire a la copie faisait passer un simple apercu pour une publication, et le
# garde-fou criait ensuite au loup. Une alerte qui se trompe finit ignoree.
$aTracer = @()

Etape 'Copie'
$version = Get-TocVersion (Join-Path $LcmAddOns ($LcmAddonFolder + '\' + $LcmAddonFolder + '.toc'))
Copy-Addon (Join-Path $LcmAddOns $LcmAddonFolder) (Join-Path $clone $LcmAddonFolder)
Copy-Addon (Join-Path $LcmAddOns $LcmMasterFolder) (Join-Path $clone $LcmMasterFolder)

# Le banc de test part avec l'addon : sans lui, personne d'autre ne peut
# verifier son travail sans lancer le jeu. Les fichiers stables (lanceur,
# installeur, mode d'emploi) vivent dans Banc\ ; le moteur et les scenarios
# sont recopies depuis la copie de travail, pour ne pas en tenir deux versions.
$bancSource = Join-Path (Split-Path $PSScriptRoot -Parent) 'Banc'
$bancCible = Join-Path $clone 'Banc'
if (Test-Path -LiteralPath $bancSource) {
    $tracesBanc = Join-Path $bancSource '.publie'
    if (-not (Test-Path -LiteralPath $tracesBanc)) { New-Item -ItemType Directory -Force -Path $tracesBanc | Out-Null }

    # Memes precautions que pour les fichiers de racine : le mode d'emploi du
    # banc se modifie aussi bien ici que dans le depot.
    #
    # Le releve se fait AVANT d'effacer Banc\, et c'est tout l'interet : la
    # verification vivait apres le Remove-Item, donc le fichier du depot
    # n'existait plus quand on voulait le comparer, `Test-Path` repondait faux
    # et le garde-fou ne se declenchait JAMAIS. Il a laisse passer une
    # republication qui annulait le mode d'emploi du banc reecrit par l'autre.
    $empreintesDepot = @{}
    foreach ($fichier in (Get-ChildItem -LiteralPath $bancSource -File)) {
        $cible = Join-Path $bancCible $fichier.Name
        if (Test-Path -LiteralPath $cible) {
            $empreintesDepot[$fichier.Name] = (Get-FileHash -LiteralPath $cible).Hash
        }
    }
    # Un fichier present dans le depot mais absent d'ici disparaitrait sans un
    # mot, efface par le Remove-Item et jamais recopie. On le rapatrie.
    #
    # Sauf ce que CE script ecrit lui-meme plus bas : le moteur du banc est
    # recopie depuis la copie de travail, il n'a rien a faire dans Banc\ ou il
    # ferait une seconde version a maintenir.
    $engendres = @('lcm_bench.py')
    if (Test-Path -LiteralPath $bancCible) {
        foreach ($fichier in (Get-ChildItem -LiteralPath $bancCible -File -Force)) {
            if ($engendres -contains $fichier.Name) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $bancSource $fichier.Name))) {
                Copy-Item -LiteralPath $fichier.FullName -Destination (Join-Path $bancSource $fichier.Name) -Force
                Alerte ('Banc' + [char]92 + $fichier.Name + " n'existait que dans le depot : recupere ici.")
            }
        }
    }

    if (Test-Path -LiteralPath $bancCible) { Remove-Item -LiteralPath $bancCible -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $bancCible 'scenarios') | Out-Null

    foreach ($fichier in (Get-ChildItem -LiteralPath $bancSource -File)) {
        $cible = Join-Path $bancCible $fichier.Name
        $trace = Join-Path $tracesBanc ($fichier.Name + '.sha')
        $avant = $empreintesDepot[$fichier.Name]
        if ($avant -and (Test-Path -LiteralPath $trace)) {
            $publie = (Get-Content -LiteralPath $trace -Raw).Trim()
            if ($publie -and $avant -ne $publie) {
                Stop-Erreur ('Banc' + [char]92 + $fichier.Name + " a ete modifie dans le depot depuis la derniere publication. Reporte ces changements dans Banc" + [char]92 + $fichier.Name + ", puis relance.")
            }
        }
        Copy-Item -LiteralPath $fichier.FullName -Destination $cible -Force
        $aTracer += @{ trace = $trace; cible = $cible }
    }
    $moteur = Join-Path $LcmBanc 'scenarios\lcm_bench.py'
    if (-not (Test-Path -LiteralPath $moteur)) { Stop-Erreur "banc introuvable : $moteur" }
    Copy-Item -LiteralPath $moteur -Destination (Join-Path $bancCible 'lcm_bench.py') -Force
    $scenarios = Get-ChildItem -LiteralPath (Join-Path $LcmBanc 'scenarios') -Filter 'lcm_test_*.lua'
    foreach ($scenario in $scenarios) {
        Copy-Item -LiteralPath $scenario.FullName -Destination (Join-Path $bancCible ('scenarios\' + $scenario.Name)) -Force
    }
    Ok (($scenarios | Measure-Object).Count.ToString() + ' scenario(s) de test.')
}

# Fichiers de racine du depot : ils vivent dans Depot\ et sont recopies a
# chaque publication, pour n'avoir qu'une seule version a maintenir.
$depot = Join-Path (Split-Path $PSScriptRoot -Parent) 'Depot'
if (Test-Path -LiteralPath $depot) {
    # Empreinte de ce qu'on a publie la derniere fois. Elle permet de distinguer
    # « j'ai modifie la source » de « quelqu'un a modifie le fichier DANS le
    # depot » — a deux sur un depot, le second est une perte silencieuse.
    $traces = Join-Path $depot '.publie'
    if (-not (Test-Path -LiteralPath $traces)) { New-Item -ItemType Directory -Force -Path $traces | Out-Null }
    foreach ($fichier in (Get-ChildItem -LiteralPath $depot -File)) {
        $cible = Join-Path $clone $fichier.Name
        $trace = Join-Path $traces ($fichier.Name + '.sha')
        if ((Test-Path -LiteralPath $cible) -and (Test-Path -LiteralPath $trace)) {
            $publie = (Get-Content -LiteralPath $trace -Raw).Trim()
            $actuel = (Get-FileHash -LiteralPath $cible).Hash
            if ($actuel -ne $publie) {
                Stop-Erreur ($fichier.Name + " a ete modifie dans le depot depuis la derniere publication. Reporte ces changements dans Depot" + [char]92 + $fichier.Name + ", puis relance.")
            }
        }
        Copy-Item -LiteralPath $fichier.FullName -Destination $cible -Force
        $aTracer += @{ trace = $trace; cible = $cible }
    }
    Ok ((Get-ChildItem -LiteralPath $depot -File | Measure-Object).Count.ToString() + ' fichier(s) de racine.')
}

# ----- l'outillage --------------------------------------------------------
# Les scripts de publication et de recuperation partent eux aussi. Sans ca
# chaque machine avait les siens, et un correctif de l'un ne parvenait jamais a
# l'autre : le garde-fou repare d'un cote restait casse de l'autre, en silence.
#
# `lcm.config.ps1` reste LOCAL : il porte les chemins de la machine (dossier
# AddOns, copie de travail du banc). Le publier remplacerait ceux de l'autre.
$outils = $PSScriptRoot
$outilsCible = Join-Path $clone 'Outils'
if (-not (Test-Path -LiteralPath $outilsCible)) { New-Item -ItemType Directory -Force -Path $outilsCible | Out-Null }
$tracesOutils = Join-Path $outils '.publie'
if (-not (Test-Path -LiteralPath $tracesOutils)) { New-Item -ItemType Directory -Force -Path $tracesOutils | Out-Null }
$horsPublication = @('lcm.config.ps1')
$nOutils = 0
foreach ($fichier in (Get-ChildItem -LiteralPath $outils -File)) {
    if ($horsPublication -contains $fichier.Name) { continue }
    if ($fichier.Extension -notin @('.ps1', '.py', '.bat', '.md')) { continue }
    $cible = Join-Path $outilsCible $fichier.Name
    $trace = Join-Path $tracesOutils ($fichier.Name + '.sha')
    # Meme garde-fou que les fichiers de racine : si le depot a bouge depuis
    # notre derniere publication, c'est que l'autre y a touche.
    if ((Test-Path -LiteralPath $cible) -and (Test-Path -LiteralPath $trace)) {
        $publie = (Get-Content -LiteralPath $trace -Raw).Trim()
        if ($publie -and (Get-FileHash -LiteralPath $cible).Hash -ne $publie) {
            Stop-Erreur ('Outils' + [char]92 + $fichier.Name + " a ete modifie dans le depot depuis la derniere publication. Recupere-le, reporte tes changements, puis relance.")
        }
    }
    Copy-Item -LiteralPath $fichier.FullName -Destination $cible -Force
    $aTracer += @{ trace = $trace; cible = $cible }
    $nOutils++
}
Ok ("$nOutils fichier(s) d'outillage.")

# Les raccourcis que l'utilisateur lance vivent a la racine du dossier de
# travail. Ils voyagent aussi, afin que le binome obtienne exactement les memes
# boutons et le meme mode d'emploi apres une recuperation.
$racineLocale = Split-Path $PSScriptRoot -Parent
foreach ($nom in @('Base - Recuperer.bat', 'Base - Envoyer.bat', 'GUIDE_BASE_COMMUNE.md')) {
    $source = Join-Path $racineLocale $nom
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $clone $nom) -Force }
}

# Aucune normalisation de fins de ligne : ce qui arrive doit etre identique.
Set-Content -LiteralPath (Join-Path $clone '.gitattributes') -Value @(
    '# Depot de distribution : aucune normalisation.',
    '* -text'
) -Encoding ASCII
Set-Content -LiteralPath (Join-Path $clone 'VERSION.txt') -Value @(
    'Les Contes Malveillants',
    ('Version ' + $version),
    ('Publie le ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')),
    '',
    'LesContesMalveillants      : l''addon, pour tout le monde.',
    'LesContesMalveillants_MJ   : contenu du maitre du jeu, a ne pas distribuer.'
) -Encoding UTF8

if ($Apercu) {
    Alerte ('Apercu : rien n''a ete pousse. Contenu pret dans ' + $clone)
    Pause-Fin 'Appuyez sur Entree pour fermer'
    exit 0
}

Etape 'Envoi'
# PowerShell enveloppe la sortie d'erreur d'un executable natif en erreur
# terminante : `git push`, qui ecrit son avancement sur stderr, faisait donc
# AVORTER le script juste apres un envoi reussi — et tout ce qui suit (les
# empreintes, le message de fin) ne tournait jamais. On rend la main au script,
# qui verifie de toute facon $LASTEXITCODE lui-meme.
$ancienneReaction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

& git -C $clone add -A
$modifs = & git -C $clone status --porcelain
if (-not $modifs) {
    Alerte 'Rien de nouveau : le depot est deja a jour.'
} else {
    Info (($modifs | Measure-Object).Count.ToString() + ' fichier(s) modifie(s).')
    if ($Message -eq '') { $Message = 'Version ' + $version + ' - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    & git -C $clone commit -q -m $Message
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'le commit a echoue.' }
    & git -C $clone push -u origin $LcmBranch
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'le push a echoue (droits ou identifiants GitHub ?).' }
    Ok ('Publie en version ' + $version + '.')
}

# Le commit qu'on vient de publier devient la base connue de cette machine.
$apres = (& git -C $clone rev-parse HEAD 2>$null)
if ($apres) {
    $dossierTrace = Split-Path $traceBase -Parent
    if (-not (Test-Path -LiteralPath $dossierTrace)) { New-Item -ItemType Directory -Force -Path $dossierTrace | Out-Null }
    Set-Content -LiteralPath $traceBase -Value $apres.Trim() -Encoding UTF8
}

foreach ($t in $aTracer) {
    Set-Content -LiteralPath $t.trace -Value (Get-FileHash -LiteralPath $t.cible).Hash -Encoding ASCII
}
$ErrorActionPreference = $ancienneReaction

Write-Host ''
Pause-Fin 'Appuyez sur Entree pour fermer'
