param([string]$CheminWoW = '')

$ErrorActionPreference = 'Stop'

function Trouver-AddOns([string]$entree) {
    $entree = $entree.Trim().Trim('"')
    if (-not $entree) { throw 'Indique le dossier _retail_ ou Interface\AddOns.' }
    $chemin = [System.IO.Path]::GetFullPath($entree)
    $candidats = @(
        $chemin,
        (Join-Path $chemin 'Interface\AddOns'),
        (Join-Path $chemin '_retail_\Interface\AddOns')
    )
    foreach ($candidat in $candidats) {
        if ((Test-Path -LiteralPath (Join-Path $candidat 'LesContesMalveillants\LesContesMalveillants.toc')) -and
            (Test-Path -LiteralPath (Join-Path $candidat 'LesContesMalveillants_MJ\LesContesMalveillants_MJ.toc'))) {
            return $candidat
        }
    }
    throw 'Les deux addons LCM (joueur et MJ) sont introuvables dans ce dossier.'
}

try {
    Write-Host 'Transfert de la base des Contes Malveillants' -ForegroundColor Cyan
    Write-Host 'WoW doit etre completement ferme.'
    if (-not $CheminWoW) {
        $CheminWoW = Read-Host 'Chemin du dossier _retail_ (ou Interface\AddOns)'
    }
    $addons = Trouver-AddOns $CheminWoW
    $retail = Split-Path (Split-Path $addons -Parent) -Parent
    $comptes = @(Get-ChildItem -LiteralPath (Join-Path $retail 'WTF\Account') -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SavedVariables\LesContesMalveillants_MJ.lua') })
    if ($comptes.Count -eq 0) {
        throw 'Aucune sauvegarde MJ trouvee dans WTF\Account. Lance une fois les deux addons sur le compte destinataire, puis ferme WoW.'
    }
    if ($comptes.Count -eq 1) {
        $compte = $comptes[0]
    } else {
        $plusRecent = $comptes | Sort-Object {
            (Get-Item -LiteralPath (Join-Path $_.FullName 'SavedVariables\LesContesMalveillants_MJ.lua')).LastWriteTime
        } -Descending | Select-Object -First 1
        Write-Host 'Comptes disponibles :'
        for ($i = 0; $i -lt $comptes.Count; $i++) {
            Write-Host ("{0}. {1}" -f ($i + 1), $comptes[$i].Name)
        }
        while (-not $compte) {
            $choix = (Read-Host ("Numero ou nom du compte (Entree = {0})" -f $plusRecent.Name)).Trim()
            if (-not $choix) {
                $compte = $plusRecent
            } else {
                $numero = 0
                if ([int]::TryParse($choix, [ref]$numero) -and $numero -ge 1 -and $numero -le $comptes.Count) {
                    $compte = $comptes[$numero - 1]
                } else {
                    $compte = $comptes | Where-Object { $_.Name -ieq $choix } | Select-Object -First 1
                }
                if (-not $compte) { Write-Host 'Choix inconnu. Utilise un numero affiche, un nom affiche ou Entree.' -ForegroundColor Yellow }
            }
        }
    }

    $source = Join-Path $PSScriptRoot 'Contenu'
    $import = Join-Path $PSScriptRoot 'Import_Brouillons.lua'
    $manifest = Join-Path $PSScriptRoot 'Manifest.json'
    if (-not (Test-Path -LiteralPath $import)) { throw 'Fichier Import_Brouillons.lua absent.' }
    if (-not (Test-Path -LiteralPath $manifest)) { throw 'Fichier Manifest.json absent.' }
    $nombre = (Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json).definitions
    $fichiers = @(Get-ChildItem -LiteralPath $source -Recurse -File -Filter '*.lua')
    if ($fichiers.Count -eq 0) { throw 'Fichiers de contenu absents.' }
    $sauvegarde = Join-Path $retail ('Sauvegarde_LCM_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $sauvegarde -Force | Out-Null
    $sv = Join-Path $compte.FullName 'SavedVariables\LesContesMalveillants_MJ.lua'
    $svRelatif = Join-Path ('WTF\Account\' + $compte.Name) 'SavedVariables\LesContesMalveillants_MJ.lua'
    $svBackup = Join-Path $sauvegarde $svRelatif
    New-Item -ItemType Directory -Path (Split-Path $svBackup -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $sv -Destination $svBackup

    foreach ($file in $fichiers) {
        $relatif = $file.FullName.Substring($source.Length).TrimStart('\', '/')
        $destination = Join-Path $addons $relatif
        if (Test-Path -LiteralPath $destination) {
            $backup = Join-Path $sauvegarde (Join-Path 'Interface\AddOns' $relatif)
            New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination $backup
        }
    }

    foreach ($file in $fichiers) {
        $relatif = $file.FullName.Substring($source.Length).TrimStart('\', '/')
        $destination = Join-Path $addons $relatif
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }

    $marqueur = '-- LCM-TRANSFERT-BASE-v1'
    $texte = [System.IO.File]::ReadAllText($sv, [System.Text.Encoding]::UTF8)
    if (-not $texte.Contains($marqueur)) {
        $payload = [System.IO.File]::ReadAllText($import, [System.Text.Encoding]::UTF8)
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::AppendAllText($sv, "`r`n" + $marqueur + "`r`n" + $payload + "`r`n", $utf8)
        Write-Host ("{0} definitions ajoutees aux brouillons MJ." -f $nombre) -ForegroundColor Green
    } else {
        Write-Host 'Brouillons MJ deja injectes : import ignore.' -ForegroundColor Yellow
    }
    Write-Host ("{0} fichiers de contenu installes." -f $fichiers.Count) -ForegroundColor Green
    Write-Host ("Compte : {0}" -f $compte.Name)
    Write-Host ("Sauvegarde : {0}" -f $sauvegarde)
    Write-Host 'Tu peux relancer WoW.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('ERREUR : ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
