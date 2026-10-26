@echo off
rem T3 Portable: double-click to start T3 Code. T3 Code, Claude Code, Codex, Git,
rem your sign-ins and your threads all live in this folder. Nothing is installed.
setlocal EnableExtensions DisableDelayedExpansion
title T3 Code
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

rem T3 Code release train to follow: stable, nightly or preview.
if not defined T3CODE_CHANNEL set "T3CODE_CHANNEL=nightly"
set "T3CODE_HOME=%ROOT%\data\t3"
set "T3CODE_INSTALL_BIN_DIR=%ROOT%\bin"
rem Only this computer can reach T3, which also avoids a firewall prompt that needs admin.
if not defined T3CODE_HOST set "T3CODE_HOST=127.0.0.1"
set "T3CODE_AUTO_BOOTSTRAP_PROJECT_FROM_CWD=false"
set "CLAUDE_CONFIG_DIR=%ROOT%\data\claude"
set "CODEX_HOME=%ROOT%\data\codex"
rem Claude's own updater writes to the user profile; setup.cmd updates it here instead.
set "DISABLE_AUTOUPDATER=1"
rem Trust certificates the school adds to Windows, for networks that inspect HTTPS.
set "NODE_USE_SYSTEM_CA=1"

if "%~1"=="open" goto :open_when_ready
rem Started again while T3 is running: open another window onto it.
call :open && exit /b 0

if not exist "%ROOT%\data" mkdir "%ROOT%\data"
if not exist "%T3CODE_HOME%\runtime\versions" echo First start: downloading T3 Code, Claude Code and Git. This can take a few minutes.
rem A Claude Code update downloaded during the last session.
if exist "%ROOT%\bin\claude.exe.new" move /y "%ROOT%\bin\claude.exe.new" "%ROOT%\bin\claude.exe" >nul 2>&1
call "%ROOT%\scripts\setup.cmd" || echo Some downloads did not finish. T3 Portable will try again next time.

rem Newest complete T3 Code version.
set "T3EXE="
for /f "delims=" %%v in ('dir /b /ad /o:d "%T3CODE_HOME%\runtime\versions" 2^>nul ^| findstr /v /b /c:"."') do (
  if exist "%T3CODE_HOME%\runtime\versions\%%v\.install-complete" set "T3EXE=%T3CODE_HOME%\runtime\versions\%%v\t3.exe"
)
if not defined T3EXE (
  echo.
  echo T3 Code could not be downloaded. Check the internet connection, then start again.
  pause
  exit /b 1
)

rem The t3 command for T3's terminal, repointed in case this folder moved.
> "%ROOT%\bin\t3.cmd" echo @echo off
>> "%ROOT%\bin\t3.cmd" echo "%T3EXE%" %%*

if exist "%ROOT%\tools\git\cmd\git.exe" (
  set "PATH=%ROOT%\tools\git\cmd;%PATH%"
  set "CLAUDE_CODE_GIT_BASH_PATH=%ROOT%\tools\git\bin\bash.exe"
)
set "PATH=%ROOT%\bin;%PATH%"

rem Look for updates in the background. They apply the next time T3 Code starts.
start "" /b cmd /c call "%ROOT%\scripts\setup.cmd" update
rem Open T3 in its own window once the server is up, instead of a browser tab.
start "" /b cmd /c call "%~f0" open
set "T3CODE_NO_BROWSER=true"

if not exist "%ROOT%\projects" mkdir "%ROOT%\projects"
cd /d "%ROOT%\projects"
echo.
echo T3 Code is starting and opens in its own window. Keep this window open while
echo you work. Close it to quit.
echo.
"%T3EXE%" start
if errorlevel 1 pause
exit /b

:open_when_ready
rem Waits a few minutes for the server, then opens it.
for /l %%i in (1,1,60) do (
  call :open && exit /b 0
  ping -n 3 127.0.0.1 >nul
)
echo T3 Code did not open by itself. Double-click "T3 Code.cmd" again to open it.
exit /b 1

:open
rem Opens T3 with a fresh sign-in link in an Edge app window (no tabs or address
rem bar), or in the default browser without Edge. Fails when T3 is not running.
set "URL="
for /f "tokens=1,2,*" %%a in ('call "%ROOT%\bin\t3.cmd" pair --ttl 2m 2^>nul') do if "%%a %%b"=="Pairing URL:" set "URL=%%c"
if not defined URL exit /b 1
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if exist "%EDGE%" (start "" "%EDGE%" --app="%URL%") else start "" "%URL%"
exit /b 0
