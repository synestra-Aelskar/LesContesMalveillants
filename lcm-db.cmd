@echo off
setlocal
cd /d "%~dp0"

set "PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%PYTHON%" goto run

where py >nul 2>nul
if not errorlevel 1 (
  py -3 database\lcm_db.py %*
  exit /b %errorlevel%
)

set "PYTHON=python"

:run
"%PYTHON%" database\lcm_db.py %*
exit /b %errorlevel%
