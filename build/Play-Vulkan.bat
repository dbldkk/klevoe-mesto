@echo off
cd /d "%~dp0"
start "" "KlevoeMesto.exe" --rendering-method forward_plus --rendering-driver vulkan %*
