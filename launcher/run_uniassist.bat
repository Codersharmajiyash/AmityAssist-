@echo off
REM ==============================================================================
REM UniAssist — Windows Staff Desktop Launcher & Auto-Updater
REM Lead Architect: Abhishek Shrivastava
REM ==============================================================================
title UniAssist Desktop Client
set SERVER_URL=https://uniassist.university.edu
echo [1/3] Checking connection to university server...
curl -s --head %SERVER_URL%/api/system/version > nul
if %errorlevel% neq 0 (
    echo [WARNING] Server unreachable or working in offline mode.
    goto LAUNCH_APP
)
echo [2/3] Checking for software updates...
REM Downloads new executable only if server timestamp is newer (-z)
curl -s -z UniAssist.exe %SERVER_URL%/dist/UniAssist.exe -o UniAssist_update.exe
if exist UniAssist_update.exe (
    echo [UPDATE] New version found. Applying update...
    move /y UniAssist_update.exe UniAssist.exe > nul
    echo [UPDATE] Update applied successfully!
)
:LAUNCH_APP
echo [3/3] Launching UniAssist...
start "" UniAssist.exe
exit

