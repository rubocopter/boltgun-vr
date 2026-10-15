@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Menu.ps1"
set "menu_result=%errorlevel%"
if not "%menu_result%"=="0" pause
exit /b %menu_result%
