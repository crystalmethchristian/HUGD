@echo off
echo Uninstalling Grafana Dashboard Stack...
set INSTALL_DIR=%USERPROFILE%\grafana-dashboard

taskkill /F /IM windows_exporter.exe >nul 2>&1
taskkill /F /IM prometheus.exe >nul 2>&1
taskkill /F /IM grafana.exe >nul 2>&1

if exist "%INSTALL_DIR%" (
    rmdir /S /Q "%INSTALL_DIR%"
)

echo Uninstallation complete.
pause
