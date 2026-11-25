@echo off
cd /d "%~dp0"
start "" "KlevoeMesto.exe" --rendering-method gl_compatibility --rendering-driver opengl3 %*
