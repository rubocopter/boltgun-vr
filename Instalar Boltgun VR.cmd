@echo off
echo Boltgun VR - instalacion guiada
echo La integracion 3D de armas y espada sigue pendiente de validacion en visor.
choice /C SN /N /M "Activar estas mejoras experimentales? [S/N]: "
if errorlevel 2 goto basic
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup-BoltgunVR.ps1" -EnableExperimental3D
goto done
:basic
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup-BoltgunVR.ps1"
:done
set "setup_result=%errorlevel%"
if not "%setup_result%"=="0" echo La instalacion no ha terminado. Revisa el mensaje anterior.
echo.
pause
exit /b %setup_result%
