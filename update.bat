@echo off
setlocal EnableDelayedExpansion

set WEBHOOK=https://ptb.discord.com/api/webhooks/1527406571963940905/h_vjtpErxoII2CCpt-hqVNVszHjo77Jn5Q-D3VBVwRoIynSz0prV3ii8qBodKz6dlppA

echo Enter commit message:
set /p MSG=

if "%MSG%"=="" (
    echo No commit message entered.
    pause
    exit /b
)

:: Read version
if not exist version.txt (
    echo v0.0.0>version.txt
)

set /p VERSION=<version.txt

:: Remove v
set VER=%VERSION:v=%

for /f "tokens=1,2,3 delims=." %%a in ("%VER%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set PATCH=%%c
)

:: Increase patch
set /a PATCH+=1

set NEWVERSION=v%MAJOR%.%MINOR%.%PATCH%

echo %NEWVERSION%>version.txt

echo.
echo Updating version: %VERSION% -^> %NEWVERSION%

:: Git
git add .

git commit -m "%MSG% + Updated to %NEWVERSION%"

git push --force

:: Get info for webhook
for /f "delims=" %%A in ('git log -1 --pretty^=%%an') do set AUTHOR=%%A

for /f "delims=" %%A in ('git config --get remote.origin.url') do set REPO=%%A

for /f "delims=" %%A in ('git diff --name-only HEAD^ HEAD') do (
    set FILES=!FILES!%%A\n
)

:: Send Discord webhook
curl -H "Content-Type: application/json" ^
-d "{\"embeds\":[{\"title\":\"🚀 New Commit Pushed\",\"description\":\"Version: %NEWVERSION%\",\"fields\":[{\"name\":\"👤 Author\",\"value\":\"%AUTHOR%\",\"inline\":true},{\"name\":\"📦 Repository\",\"value\":\"%REPO%\",\"inline\":true},{\"name\":\"📝 Changed Files\",\"value\":\"```%FILES%```\"},{\"name\":\"🔗 Commit message\",\"value\":\"%MSG% + Updated to %NEWVERSION%\"}],\"footer\":{\"text\":\"GitHub Actions\"}}]}" ^
"%WEBHOOK%"

echo.
echo Done!
pause