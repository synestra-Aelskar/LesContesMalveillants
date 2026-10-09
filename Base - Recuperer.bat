@echo off
title Les Contes Malveillants - recuperer la base
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Outils\base.ps1" -Mode recuperer
pause
