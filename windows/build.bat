@echo off
cd /d "%~dp0.."
docker compose run --build --rm pishrink
rem Shutdown disabled. Remove "rem" to shut down the PC 30 s after the run.
rem shutdown /s /f /t 30
pause
