@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Play-BoltgunVR.ps1"
if errorlevel 1 pause
