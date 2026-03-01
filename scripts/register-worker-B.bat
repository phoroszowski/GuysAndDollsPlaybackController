@echo off
:: Run as Administrator on Machine B (worker)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register-tasks.ps1" -ConfigFile config.worker-B.json -Username GuysAndDolls
pause
