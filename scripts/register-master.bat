@echo off
:: Run as Administrator on Machine A (master)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register-tasks.ps1" -Master -Username GuysAndDolls
pause
