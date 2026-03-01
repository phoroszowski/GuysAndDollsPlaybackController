@echo off
:: Run as Administrator on Machine C (worker)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register-tasks.ps1" -ConfigFile config.worker-C.json -Username GuysAndDolls
pause
