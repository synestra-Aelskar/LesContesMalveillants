@echo off
setlocal
title Installation de la synchronisation LCM

echo Installation du surveillant Google Sheets LCM
echo.
set /p "SHEET_ID=Identifiant du classeur Google Sheets : "
if "%SHEET_ID%"=="" goto :incomplet
set /p "CREDENTIALS=Chemin complet du JSON du compte de service : "
if "%CREDENTIALS%"=="" goto :incomplet

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer_sync.ps1" -SheetId "%SHEET_ID%" -Credentials "%CREDENTIALS%"
if errorlevel 1 goto :echec
echo.
echo Installation terminee. La tache est demarree en arriere-plan.
goto :fin

:incomplet
echo Les deux informations sont necessaires. Rien n'a ete installe.
goto :fin

:echec
echo.
echo L'installation a echoue. Lis le message ci-dessus et corrige le probleme.

:fin
echo.
pause
endlocal
