@echo off
cd /d "%~dp0.."
docker compose up --build
shutdown /s /f /t 30
