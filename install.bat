@echo off
echo ================================================
echo   Installing Power Management Service...
echo ================================================
echo.

set "DEST=%APPDATA%\PowerManagementSvc"

mkdir "%DEST%" 2>nul
mkdir "%DEST%\sounds\plug" 2>nul
mkdir "%DEST%\sounds\unplug" 2>nul

copy /y "%~dp0soundcharge.ps1" "%DEST%\" >nul
robocopy "%~dp0sounds\plug" "%DEST%\sounds\plug" *.mp3 /NFL /NDL /NJH /NJS >nul
robocopy "%~dp0sounds\unplug" "%DEST%\sounds\unplug" *.mp3 /NFL /NDL /NJH /NJS >nul

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "PowerManagementSvc" /t REG_SZ /d "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%DEST%\soundcharge.ps1\"" /f >nul

start "" powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%DEST%\soundcharge.ps1"

echo   [OK] Installed to %DEST%
echo   [OK] Added to startup
echo   [OK] Running now
echo.
echo   You can DELETE this entire folder now.
echo.
pause
