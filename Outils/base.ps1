param(
    [ValidateSet('recuperer', 'envoyer', 'importer', 'construire', 'status')]
    [string]$Mode = 'status',
    [string]$Message = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lcm.config.ps1')

function Etape($texte) { Write-Host ''; Write-Host ('=== ' + $texte) -ForegroundColor Cyan }
function Info($texte) { Write-Host ('    ' + $texte) -ForegroundColor Gray }
function Ok($texte) { Write-Host ('    ' + $texte) -ForegroundColor Green }
function Stop-Erreur($texte) {
    Write-Host ''; Write-Host ('ERREUR : ' + $texte) -ForegroundColor Red; Write-Host ''
    try { Read-Host 'Appuyez sur Entree pour fermer' | Out-Null } catch { }
    exit 1
}

function Python-Disponible {
    if ($LcmPython -and (Test-Path -LiteralPath $LcmPython)) { return $LcmPython }
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { return $py.Source }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return $python.Source }
    return $null
}

$clone = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.publication'))
$scriptBase = Join-Path $clone 'database\lcm_db.py'
$python = Python-Disponible
if (-not $python) { Stop-Erreur 'Python est introuvable.' }
if (-not (Test-Path -LiteralPath (Join-Path $clone '.git'))) { Stop-Erreur 'clone Git introuvable.' }
if (-not (Test-Path -LiteralPath $scriptBase)) { Stop-Erreur 'base commune absente du depot.' }

function Executer-Base([string[]]$Arguments) {
    $ancienAddons = $env:LCM_ADDONS
    try {
        $env:LCM_ADDONS = $LcmAddOns
        if ((Split-Path $python -Leaf).ToLower() -eq 'py.exe') {
            & $python -3 $scriptBase @Arguments
        } else {
            & $python $scriptBase @Arguments
        }
        if ($LASTEXITCODE -ne 0) { Stop-Erreur ('commande de base echouee : ' + ($Arguments -join ' ')) }
    } finally {
        $env:LCM_ADDONS = $ancienAddons
    }
}

function Ecrire-BaseConnue {
    $sha = (& git -C $clone rev-parse HEAD 2>$null)
    if (-not $sha) { return }
    $trace = Join-Path $PSScriptRoot '.publie\base.sha'
    $dossier = Split-Path $trace -Parent
    if (-not (Test-Path -LiteralPath $dossier)) { New-Item -ItemType Directory -Force -Path $dossier | Out-Null }
    Set-Content -LiteralPath $trace -Value $sha.Trim() -Encoding ASCII
}

if ($Mode -eq 'importer') {
    Etape 'Import des brouillons'
    Executer-Base @('import')
    Executer-Base @('build')
    exit 0
}

if ($Mode -eq 'construire') {
    Etape 'Reconstruction des addons'
    Executer-Base @('build')
    Ok 'Les deux fichiers Atelier.lua ont ete reconstruits.'
    exit 0
}

if ($Mode -eq 'status') {
    Executer-Base @('status')
    exit 0
}

if ($Mode -eq 'recuperer') {
    Etape 'Recuperation de la base commune'
    $sale = & git -C $clone status --porcelain
    if ($sale) {
        Stop-Erreur 'Le clone contient des changements locaux. Envoie-les d''abord, ou annule ton apercu de publication.'
    }
    & git -C $clone fetch origin --prune
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'GitHub est inaccessible.' }
    & git -C $clone checkout $LcmBranch --quiet
    & git -C $clone merge --ff-only ('origin/' + $LcmBranch)
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'La recuperation demande une intervention Git manuelle.' }
    Executer-Base @('build')
    Ecrire-BaseConnue
    Ok 'Base recuperee et addons reconstruits. Fais /reload dans WoW.'
    exit 0
}

if ($Mode -eq 'envoyer') {
    Etape 'Verification du depot'
    $horsBase = & git -C $clone status --porcelain -- . ':(exclude)database'
    if ($horsBase) {
        Stop-Erreur 'Une publication d''addon est en preparation. Termine-la ou recupere le depot avant d''envoyer la base.'
    }
    & git -C $clone fetch origin --prune
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'GitHub est inaccessible.' }
    $local = (& git -C $clone rev-parse HEAD).Trim()
    $distant = (& git -C $clone rev-parse ('origin/' + $LcmBranch)).Trim()
    if ($local -ne $distant) {
        Stop-Erreur 'Le depot a avance. Lance d''abord « Recuperer.bat », puis recommence.'
    }

    Etape 'Import des brouillons'
    Executer-Base @('import')
    Executer-Base @('build')
    & git -C $clone add -- database
    $modifs = & git -C $clone diff --cached --name-only -- database
    if (-not $modifs) {
        Ok 'Aucun nouveau brouillon : la base est deja a jour.'
        exit 0
    }

    if ($Message -eq '') { $Message = 'Base commune - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    Info (($modifs | Measure-Object).Count.ToString() + ' fichier(s) de contenu modifie(s).')
    & git -C $clone commit -m $Message
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'Le commit a echoue. Verifie ton nom et ton adresse Git.' }
    & git -C $clone push origin $LcmBranch
    if ($LASTEXITCODE -ne 0) { Stop-Erreur 'Le push a echoue. Ne recommence pas : recupere d''abord les changements distants.' }
    Ecrire-BaseConnue
    Ok 'Base commune envoyee sur GitHub.'
    exit 0
}
