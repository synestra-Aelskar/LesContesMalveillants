@echo off
setlocal
cd /d "%~dp0"
echo Creation de l environnement Python du banc...
python -m venv .venv
if errorlevel 1 (
  echo Python introuvable. Installe Python 3 puis relance.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" -m pip install --quiet --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt
echo.
echo Pret. Essaie : lcm.cmd scenarios\lcm_test_socle.lua
pause
