param(
    [Parameter(Mandatory = $true)][string]$SheetId,
    [Parameter(Mandatory = $true)][string]$Credentials,
    [string]$Retail
)

$ErrorActionPreference = 'Stop'
$racine = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script = Join-Path $PSScriptRoot 'gsheet_auto.py'
$cle = (Resolve-Path -LiteralPath $Credentials).Path
if (-not $Retail -and (Split-Path $racine -Leaf) -eq 'Sync') {
    $Retail = (Resolve-Path -LiteralPath (Join-Path $racine '..\..\..\..')).Path
}
if (-not $Retail) { throw 'Préciser -Retail (dossier _retail_ de WoW).' }
$jeu = (Resolve-Path -LiteralPath $Retail).Path
if (-not (Test-Path -LiteralPath (Join-Path $jeu 'WTF\Account'))) {
    throw "Dossier WTF\Account absent : $jeu"
}
$python = $null
# `python` pointe parfois vers l'alias Microsoft Store, meme si Python est
# installe. Preferer un interpreteur reel dans PATH, puis retomber sur le
# lanceur officiel `py`.
$candidats = Get-Command python.exe -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -and $_.Source -notmatch '[\\/]WindowsApps[\\/]' }
foreach ($candidat in $candidats) {
    $essai = (& $candidat.Source -c 'import sys; print(sys.executable)' 2>$null).Trim()
    if ($LASTEXITCODE -eq 0 -and $essai -and (Test-Path -LiteralPath $essai)) {
        $python = $essai
        break
    }
}
if (-not $python) {
    $lanceur = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($lanceur) {
        $essai = (& $lanceur.Source -3 -c 'import sys; print(sys.executable)' 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $essai -and (Test-Path -LiteralPath $essai)) { $python = $essai }
    }
}
if (-not $python) { throw 'Python introuvable. Installe Python 3 puis reessaie.' }
$modules = & $python -c 'import google.auth, requests, watchdog, psutil' 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Dependances Python manquantes. Execute : `"$python`" -m pip install --user google-auth requests watchdog psutil"
}
$pythonw = Join-Path (Split-Path $python -Parent) 'pythonw.exe'
if (-not (Test-Path -LiteralPath $pythonw)) { throw "pythonw.exe introuvable : $pythonw" }

function Citer([string]$valeur) { return '"' + $valeur.Replace('"', '\"') + '"' }
$arguments = (Citer $script) + ' watch --sheet-id ' + (Citer $SheetId) +
    ' --credentials ' + (Citer $cle) + ' --retail ' + (Citer $jeu)
$action = New-ScheduledTaskAction -Execute $pythonw -Argument $arguments -WorkingDirectory $racine
$utilisateur = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$declencheur = New-ScheduledTaskTrigger -AtLogOn -User $utilisateur
$parametres = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $utilisateur -LogonType Interactive -RunLevel Limited
$nom = 'LCM Google Sheets Sync'
Register-ScheduledTask -TaskName $nom -Action $action -Trigger $declencheur `
    -Settings $parametres -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $nom
Write-Host "Surveillant installe et demarre : $nom"
Write-Host "Journal : $(Join-Path $racine 'Sauvegardes_LCM\synchro.log')"
