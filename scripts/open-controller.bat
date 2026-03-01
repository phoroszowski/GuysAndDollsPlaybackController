@echo off
:: open-controller.bat
:: ──────────────────────────────────────────────────────────────────────────
:: MASTER MACHINE ONLY (Machine A).
:: Copy this file to C:\ShowApp\open-controller.bat on Machine A.
::
:: Waits 10 seconds for the Node server to finish starting, then opens
:: Chrome in kiosk mode pointing at the show controller UI.
::
:: To exit kiosk mode during setup/testing: Alt+F4
:: ──────────────────────────────────────────────────────────────────────────

timeout /t 10 /nobreak > nul
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk http://localhost:3000
