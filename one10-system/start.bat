@echo off
cd /d %~dp0
start "" chrome http://localhost:3000
node server.js
pause
