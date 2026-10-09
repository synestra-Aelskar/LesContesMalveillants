@echo off
title Les Contes Malveillants - envoyer la base
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Outils\base.ps1" -Mode envoyer
pause
