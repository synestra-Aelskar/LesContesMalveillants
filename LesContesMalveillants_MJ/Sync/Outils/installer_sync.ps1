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
$python = (& python -c 'import sys; print(sys.executable)').Trim()
if ($LASTEXITCODE -ne 0 -or -not $python) { throw 'Python introuvable.' }
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
