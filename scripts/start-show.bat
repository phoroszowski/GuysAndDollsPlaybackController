@echo off
:: start-show.bat
:: ──────────────────────────────────────────────────────────────────────────
:: Place this file in the project root directory on each machine.
:: It is launched by Task Scheduler at login.
::
:: Edit the CONFIG line below for each machine:
::   Master A : node server.js                      (uses config.json)
::   Worker B  : node server.js config.worker-B.json
::   Worker C  : node server.js config.worker-C.json
::
:: VLC is launched automatically by the server on startup.
:: ──────────────────────────────────────────────────────────────────────────

cd /d C:\GuysAndDollsPlaybackController
node server.js %1 >> C:\GuysAndDollsPlaybackController\server.log 2>&1
