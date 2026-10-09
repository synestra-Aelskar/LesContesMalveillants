# Recuperation des Contes Malveillants : le depot -> ton dossier d'addon.
#
#   .\recuperer.ps1           -> recupere, apres t'avoir montre ce qui change
#   .\recuperer.ps1 -Apercu   -> montre seulement, ne touche a rien
#
# A quoi ca sert. On publie a deux, et la publication REFAIT le dossier
# d'addon du depot a partir de la machine qui publie. Travailler sur une base
# en retard, c'est donc effacer le travail de l'autre sans s'en apercevoir.
# Cet outil remet le depot dans ton dossier d'addon avant que tu reprennes.
#
# Il ne devine rien : il te montre d'abord les fichiers qui ne sont pas les
# memes des deux cotes, et c'est toi qui decides.

param(
    [switch]$Apercu,
    [switch]$DejaAJour
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

# Remet les empreintes des fichiers de racine (Depot\\ et Banc\\) sur ce que le
# depot contient AUJOURD'HUI. Dire « je suis a jour » et ne remettre a jour que
# base.sha ne suffisait pas : les empreintes par fichier restaient en retard,
# la publication bloquait quand meme, et la seule issue visible redevenait
# -Forcer, c'est-a-dire ecraser. Une empreinte dit « j'ai vu cette version du
# depot » : elle ne dit rien de ce que contient ma copie, qui peut tres bien
# avoir integre celle de l'autre PLUS mes propres ajouts.
function Maj-Empreintes($dossierSource, $dossierDepot) {
    if (-not (Test-Path -LiteralPath $dossierSource)) { return 0 }
    $traces = Join-Path $dossierSource '.publie'
    if (-not (Test-Path -LiteralPath $traces)) { New-Item -ItemType Directory -Force -Path $traces | Out-Null }
    $faits = 0
    foreach ($fichier in (Get-ChildItem -LiteralPath $dossierSource -File)) {
        $auDepot = Join-Path $dossierDepot $fichier.Name
        if (-not (Test-Path -LiteralPath $auDepot)) { continue }
        $empreinte = (Get-FileHash -LiteralPath $auDepot).Hash
        Set-Content -LiteralPath (Join-Path $traces ($fichier.Name + '.sha')) -Value $empreinte -Encoding ASCII
        $faits++
    }
    return $faits
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
$baseLocale = & git -C $clone status --porcelain -- database 2>$null
if ($baseLocale) {
    Stop-Erreur 'La base commune contient des changements non envoyes. Lance « Base - Envoyer.bat » avant de recuperer.'
}
& git -C $clone fetch origin --prune --quiet
if (-not (& git -C $clone ls-remote --heads origin $LcmBranch)) {
    Stop-Erreur ("la branche " + $LcmBranch + " n'existe pas encore sur le depot.")
}
& git -C $clone checkout -B $LcmBranch ('origin/' + $LcmBranch) --quiet
& git -C $clone reset --hard ('origin/' + $LcmBranch) --quiet
$distant = (& git -C $clone rev-parse HEAD).Trim()
Info ('depot : ' + $distant.Substring(0, 7))

# Compare un fichier du depot et son equivalent chez toi.
function Etat($depot, $local) {
    if (-not (Test-Path -LiteralPath $local)) { return 'absent chez toi' }
    $a = Get-FileHash -LiteralPath $depot -Algorithm SHA256
    $b = Get-FileHash -LiteralPath $local -Algorithm SHA256
    if ($a.Hash -eq $b.Hash) { return '' }
    return 'different'
}

Etape 'Comparaison'
$aCopier = @()
foreach ($dossier in @($LcmAddonFolder, $LcmMasterFolder)) {
    $source = Join-Path $clone $dossier
    $cible = Join-Path $LcmAddOns $dossier
    if (-not (Test-Path -LiteralPath $source)) { continue }
    foreach ($fichier in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
        $relatif = $fichier.FullName.Substring($source.Length).TrimStart('\')
        $local = Join-Path $cible $relatif
        $etat = Etat $fichier.FullName $local
        if ($etat -ne '') {
            $aCopier += [pscustomobject]@{
                Depot = $fichier.FullName; Local = $local
                Nom = (Join-Path $dossier $relatif); Etat = $etat
            }
        }
    }
}

# ----- le banc ------------------------------------------------------------
# La publication envoie le banc (moteur et scenarios) depuis la copie de
# travail ; la recuperation ne le rendait PAS. On integrait donc le code de
# l'autre sans ses tests, et on verifiait son travail a l'aveugle — deux fois
# de suite il a fallu recopier les scenarios a la main.
#
# Le chemin de retour n'est pas symetrique, parce que la publication ne l'est
# pas : le moteur part de `scenarios\lcm_bench.py` et arrive a la racine de
# `Banc\`, les scenarios gardent leur sous-dossier, et les fichiers stables
# (lanceur, installeur, mode d'emploi) vivent dans `Banc\` ici.
$bancDepot = Join-Path $clone 'Banc'
$bancLocal = Join-Path (Split-Path $PSScriptRoot -Parent) 'Banc'
# Ajoute un fichier a la liste de ce qui est a recuperer, s'il differe.
function Ajouter-Banc($depot, $local, $nom) {
    $etat = Etat $depot $local
    if ($etat -ne '') {
        $script:aCopier += [pscustomobject]@{
            Depot = $depot; Local = $local; Nom = $nom; Etat = $etat
        }
    }
}

if (Test-Path -LiteralPath $bancDepot) {
    $moteurDepot = Join-Path $bancDepot 'lcm_bench.py'
    if (Test-Path -LiteralPath $moteurDepot) {
        Ajouter-Banc $moteurDepot (Join-Path $LcmBanc 'scenarios\lcm_bench.py') 'Banc\lcm_bench.py'
    }

    $scenariosDepot = Join-Path $bancDepot 'scenarios'
    if (Test-Path -LiteralPath $scenariosDepot) {
        foreach ($fichier in (Get-ChildItem -LiteralPath $scenariosDepot -File -Filter 'lcm_test_*.lua')) {
            Ajouter-Banc $fichier.FullName (Join-Path $LcmBanc ('scenarios\' + $fichier.Name)) ('Banc\scenarios\' + $fichier.Name)
        }
    }

    # Les fichiers stables de Banc\ : ils se modifient des deux cotes, comme
    # ceux de Depot\, et c'est le garde-fou par empreinte qui tranche a la
    # publication. Ici on les rend simplement.
    foreach ($fichier in (Get-ChildItem -LiteralPath $bancDepot -File -Force)) {
        if ($fichier.Name -eq 'lcm_bench.py') { continue }
        Ajouter-Banc $fichier.FullName (Join-Path $bancLocal $fichier.Name) ('Banc\' + $fichier.Name)
    }
}

# ----- l'outillage --------------------------------------------------------
# Les scripts partagés reviennent comme le reste. `lcm.config.ps1` ne fait pas
# le voyage : il porte les chemins de CETTE machine.
$outilsDepot = Join-Path $clone 'Outils'
if (Test-Path -LiteralPath $outilsDepot) {
    foreach ($fichier in (Get-ChildItem -LiteralPath $outilsDepot -File)) {
        if ($fichier.Name -eq 'lcm.config.ps1') { continue }
        Ajouter-Banc $fichier.FullName (Join-Path $PSScriptRoot $fichier.Name) ('Outils' + [char]92 + $fichier.Name)
    }
}

# Raccourcis de la base et guide, a la racine du dossier de travail local.
$racineLocale = Split-Path $PSScriptRoot -Parent
foreach ($nom in @('Base - Recuperer.bat', 'Base - Envoyer.bat', 'GUIDE_BASE_COMMUNE.md')) {
    $source = Join-Path $clone $nom
    if (Test-Path -LiteralPath $source) {
        Ajouter-Banc $source (Join-Path $racineLocale $nom) $nom
    }
}

if ($aCopier.Count -eq 0) {
    Ok 'Ton dossier d''addon est deja celui du depot : rien a recuperer.'
} else {
    Alerte ($aCopier.Count.ToString() + ' fichier(s) ne sont pas les memes des deux cotes :')
    foreach ($f in ($aCopier | Select-Object -First 40)) {
        Info ('  ' + $f.Etat.PadRight(16) + $f.Nom)
    }
    if ($aCopier.Count -gt 40) { Info ('  ... et ' + ($aCopier.Count - 40) + ' autre(s).') }
    Write-Host ''
    Alerte 'Ce qui est DIFFERENT sera remplace par la version du depot.'
    Alerte 'Si tu as du travail en cours sur ces fichiers, mets-le de cote AVANT.'
}

if ($Apercu) {
    Write-Host ''
    Alerte ('Apercu : rien n''a ete touche. Le depot est dans ' + $clone)
    Pause-Fin 'Appuyez sur Entree pour fermer'
    exit 0
}

# « J'ai deja reporte ce qu'il fallait a la main » : on note que cette machine
# est a jour, sans rien ecraser. Sans cette porte, quelqu'un qui a integre le
# travail de l'autre autrement qu'avec cet outil reste bloque a la publication,
# et la seule issue visible serait -Forcer, c'est-a-dire ecraser.
if ($DejaAJour) {
    Write-Host ''
    Alerte 'Rien n''a ete copie : tu declares avoir deja integre ces changements.'
    $traceBase = Join-Path $PSScriptRoot '.publie\base.sha'
    $dossierTrace = Split-Path $traceBase -Parent
    if (-not (Test-Path -LiteralPath $dossierTrace)) { New-Item -ItemType Directory -Force -Path $dossierTrace | Out-Null }
    Set-Content -LiteralPath $traceBase -Value $distant -Encoding UTF8
    $racine = Split-Path $PSScriptRoot -Parent
    $n = (Maj-Empreintes (Join-Path $racine 'Depot') $clone)
    $n += (Maj-Empreintes (Join-Path $racine 'Banc') (Join-Path $clone 'Banc'))
    Ok ('Base connue mise a jour (' + $n + ' empreinte(s)) : tu peux republier.')
    Pause-Fin 'Appuyez sur Entree pour fermer'
    exit 0
}

if ($aCopier.Count -gt 0) {
    Write-Host ''
    $reponse = ''
    try { $reponse = Read-Host 'Remplacer ces fichiers par ceux du depot ? (oui/non)' } catch { }
    if ($reponse.Trim().ToLower() -ne 'oui') {
        Alerte 'Rien n''a ete touche.'
        Pause-Fin 'Appuyez sur Entree pour fermer'
        exit 0
    }

    Etape 'Recuperation'
    foreach ($f in $aCopier) {
        $dossier = Split-Path $f.Local -Parent
        if (-not (Test-Path -LiteralPath $dossier)) { New-Item -ItemType Directory -Force -Path $dossier | Out-Null }
        Copy-Item -LiteralPath $f.Depot -Destination $f.Local -Force
    }
    Ok ($aCopier.Count.ToString() + ' fichier(s) recuperes.')
}

# Cette machine est a jour : la publication n'a plus de raison de bloquer.
$traceBase = Join-Path $PSScriptRoot '.publie\base.sha'
$dossierTrace = Split-Path $traceBase -Parent
if (-not (Test-Path -LiteralPath $dossierTrace)) { New-Item -ItemType Directory -Force -Path $dossierTrace | Out-Null }
Set-Content -LiteralPath $traceBase -Value $distant -Encoding UTF8
$racine = Split-Path $PSScriptRoot -Parent
$n = (Maj-Empreintes (Join-Path $racine 'Depot') $clone)
$n += (Maj-Empreintes (Join-Path $racine 'Banc') (Join-Path $clone 'Banc'))
Ok ('Base connue mise a jour (' + $n + ' empreinte(s)) : tu peux republier.')

Write-Host ''
Alerte 'Relance WoW ou fais /reload pour voir les fichiers recuperes.'
Info  'Le banc est a jour lui aussi : relance la suite avant de reprendre.'
Info  "Si l'outillage a ete recupere, relance Recuperer.bat une fois : tu viens"
Info  "de remplacer le script qui tourne."

# Le pull a peut-etre apporte de nouvelles entrees. Elles deviennent aussitot
# les deux Atelier.lua charges par WoW.
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'base.ps1')) {
    & (Join-Path $PSScriptRoot 'base.ps1') -Mode construire
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'reconstruction depuis la base commune impossible.' }
}

Pause-Fin 'Appuyez sur Entree pour fermer'
