@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File "%~dp0Export-FlyingBirdProfile.ps1" ^
  -OpenOutputFolder

echo.
echo Finished. Press any key to close.
pause >nul
