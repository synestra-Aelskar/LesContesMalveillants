@echo off
setlocal
cd /d "%~dp0\.."
call lcm-db.cmd %*
exit /b %errorlevel%
