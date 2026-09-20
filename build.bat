@echo off
chcp 65001 >nul
:: Proje klasörüne git
cd /d "%~dp0"
:: Scripti çalıştır
if exist "%~dp0build.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
) else if exist "%~dp0scripts\build-and-deploy.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-and-deploy.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_windows.ps1"
)
pause
