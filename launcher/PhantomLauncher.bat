@echo off
rem Phantom Launcher wrapper. Keep this file next to Telegram.exe.
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0PhantomLauncher.ps1"
if errorlevel 1 (
  echo.
  echo Failed to start the launcher. Make sure PhantomLauncher.ps1 is next to this file.
  pause
)
endlocal
