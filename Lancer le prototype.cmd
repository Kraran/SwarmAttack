@echo off
setlocal
set "SWARM_ENGINE=%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%SWARM_ENGINE%" (
    echo Godot 4.7.2 est introuvable dans le dossier .tools.
    pause
    exit /b 1
)
start "" "%SWARM_ENGINE%" --path "%~dp0prototype"
