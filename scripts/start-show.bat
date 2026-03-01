@echo off
:: start-show.bat
:: ──────────────────────────────────────────────────────────────────────────
:: Copy this file to C:\ShowApp\start-show.bat on each machine.
:: Do NOT run from the project directory — it is launched by Task Scheduler
:: from C:\ShowApp\ at login.
::
:: Starts the Node.js server and appends all output to server.log.
:: VLC is launched automatically by the server on startup.
:: ──────────────────────────────────────────────────────────────────────────

cd /d C:\GuysAndDollsPlaybackController
node server.js >> C:\GuysAndDollsPlaybackController\server.log 2>&1
