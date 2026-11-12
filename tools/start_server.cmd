@echo off
rem Double-click to start the team server (127.0.0.1:8000) in a PowerShell window.
rem Runs start_server.ps1 next to this file. Stop with Ctrl+C or by closing the window.
title APT team server
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_server.ps1"
echo.
pause
