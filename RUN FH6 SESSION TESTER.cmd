@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FH6_Session_Tester.ps1"
if errorlevel 1 (
  echo.
  echo The tester exited with an error.
  echo Send a screenshot of this window back to the person who gave you the tester.
  echo.
  pause
)
