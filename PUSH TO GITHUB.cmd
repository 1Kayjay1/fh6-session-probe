@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "REPO_NAME=fh6-session-probe"
set "VISIBILITY=public"

echo.
echo ============================================
echo   FH6 Session Probe - GitHub Instant Push
echo ============================================
echo.

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git is not installed or not in PATH.
    pause
    exit /b 1
)

where gh >nul 2>nul
if errorlevel 1 (
    echo [ERROR] GitHub CLI ^(gh^) is not installed or not in PATH.
    pause
    exit /b 1
)

echo [1/6] Checking GitHub CLI login...
gh auth status >nul 2>nul
if errorlevel 1 (
    echo.
    echo GitHub CLI is not logged in.
    echo Launching: gh auth login
    echo.
    gh auth login
    if errorlevel 1 (
        echo [ERROR] GitHub authentication failed.
        pause
        exit /b 1
    )
)

for /f "delims=" %%U in ('gh api user --jq ".login" 2^>nul') do set "GH_USER=%%U"
if not defined GH_USER (
    echo [ERROR] Could not determine your GitHub username.
    pause
    exit /b 1
)

echo     Logged in as: %GH_USER%

echo [2/6] Preparing Git repository...
if not exist ".git\" (
    git init
    if errorlevel 1 goto :gitfail
)

git branch -M main >nul 2>nul

echo [3/6] Staging project files...
git add .
if errorlevel 1 goto :gitfail

git diff --cached --quiet
if errorlevel 1 (
    echo [4/6] Creating initial commit...
    git commit -m "Initial FH6 session probe"
    if errorlevel 1 (
        echo.
        echo [ERROR] Git could not create the commit.
        echo If Git asks for your name/email, run:
        echo   git config --global user.name "Your Name"
        echo   git config --global user.email "you@example.com"
        echo Then run this PUSH script again.
        pause
        exit /b 1
    )
) else (
    echo [4/6] No new changes to commit.
)

echo [5/6] Checking GitHub repository...
gh repo view "%GH_USER%/%REPO_NAME%" >nul 2>nul
if errorlevel 1 (
    echo     Creating https://github.com/%GH_USER%/%REPO_NAME%
    gh repo create "%REPO_NAME%" --%VISIBILITY% --source=. --remote=origin
    if errorlevel 1 (
        echo [ERROR] Could not create the GitHub repository.
        pause
        exit /b 1
    )
) else (
    echo     Repository already exists.
    git remote get-url origin >nul 2>nul
    if errorlevel 1 (
        git remote add origin "https://github.com/%GH_USER%/%REPO_NAME%.git"
    )
)

echo [6/6] Pushing main...
git push -u origin main
if errorlevel 1 goto :gitfail

echo.
echo ============================================
echo   PUSH COMPLETE
echo ============================================
echo.
echo https://github.com/%GH_USER%/%REPO_NAME%
echo.
echo Opening repository in your browser...
gh repo view --web
exit /b 0

:gitfail
echo.
echo [ERROR] A Git command failed.
echo Fix the message above, then run this script again.
pause
exit /b 1
