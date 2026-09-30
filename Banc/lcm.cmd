@echo off
setlocal
cd /d "%~dp0"

rem Cherche un interpreteur : le venv local du banc, puis le python du systeme.
set "PY=%~dp0.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

if "%~1"=="" (
  echo Usage : lcm.cmd scenarios\lcm_test_socle.lua
  echo Voir LISEZ-MOI.md pour l installation.
  exit /b 2
)

"%PY%" "%~dp0lcm_bench.py" %*
exit /b %errorlevel%
