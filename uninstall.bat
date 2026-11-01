@echo off
echo ================================================
echo   Uninstalling Power Management Service...
echo ================================================
echo.

wmic process where "name='powershell.exe' and commandline like '%%soundcharge%%'" call terminate >nul 2>nul
powershell -Command "Get-CimInstance Win32_Process -Filter \"CommandLine LIKE '%%soundcharge%%'\" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" 2>nul

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "PowerManagementSvc" /f >nul 2>nul

rmdir /s /q "%APPDATA%\PowerManagementSvc" 2>nul

echo   [OK] Process killed
echo   [OK] Startup entry removed
echo   [OK] Files deleted
echo.
echo   Fully uninstalled.
echo.
pause
