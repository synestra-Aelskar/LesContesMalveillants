@echo off
setlocal
title Les Contes Malveillants - transfert de la base
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installer la base.ps1" -CheminWoW "%~1"
set "RESULTAT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULTAT%
