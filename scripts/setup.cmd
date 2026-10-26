@echo off
rem Downloads what T3 Portable needs into this folder. "T3 Code.cmd" calls it:
rem   setup.cmd          before T3 starts: download anything missing
rem   setup.cmd update   in the background: stage updates for the next start
rem Downloads and checksums go through PowerShell first and fall back to the
rem curl and certutil built into Windows when PowerShell is blocked or fails.
rem Set T3P_NO_POWERSHELL=1 to skip PowerShell entirely.
setlocal EnableExtensions DisableDelayedExpansion
for %%i in ("%~dp0..") do set "ROOT=%%~fi"
set "WORK=%ROOT%\data\downloads"
set "VERSIONS=%T3CODE_HOME%\runtime\versions"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "CURL=curl -fSL --retry 2 -#"
if /i "%~1"=="update" set "CURL=curl -fsSL --retry 2"

set "ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

rem Portable Git, only downloaded when this computer has no Git of its own.
set "GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/PortableGit-2.56.0.4-64-bit.7z.exe"
set "GIT_SHA256=b1f3e52216e2ed6882d1bebfd4d3fdf319bec40d2edbbf9fd26ec4fd3fce7ed1"
if "%ARCH%"=="arm64" set "GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/PortableGit-2.56.0.4-arm64.7z.exe"
if "%ARCH%"=="arm64" set "GIT_SHA256=044110f9d951858452ddb5e4b5415ea0f2b5b2598e794d6fec77fe28b9aa8cc0"

if not exist "%WORK%" mkdir "%WORK%"
if not exist "%ROOT%\bin" mkdir "%ROOT%\bin"

if /i "%~1"=="update" (
  call :update > "%ROOT%\data\update.log" 2>&1
  exit /b
)
set "FAILED="
call :t3 || set "FAILED=1"
call :claude install || set "FAILED=1"
call :git || set "FAILED=1"
if defined FAILED exit /b 1
exit /b 0

:update
echo Update check %DATE% %TIME%
rem t3 updates itself; if it cannot (a proxy it does not know about), fetch the release here.
call "%ROOT%\bin\t3.cmd" update --yes || call :t3 newest
call :claude update
exit /b 0

:t3
rem Installs the newest T3 Code release on %T3CODE_CHANNEL%, the same way t3's
rem own installer does. Without "newest", only when no version is installed yet.
if /i not "%~1"=="newest" for /d %%v in ("%VERSIONS%\*") do if exist "%%v\.install-complete" if exist "%%v\t3.exe" exit /b 0
rem Newest tag on the channel. PowerShell reads GitHub's JSON properly. The cmd
rem fallback relies on curl getting it one key per line, which findstr can search.
set "T3P_URL=https://api.github.com/repos/pingdotgg/t3code/releases?per_page=100"
set "T3P_TAG_REGEX=^v\d+\.\d+\.\d+-%T3CODE_CHANNEL%\.\d+\.\d+$"
if /i "%T3CODE_CHANNEL%"=="stable" set "T3P_TAG_REGEX=^v\d+\.\d+\.\d+$"
set "TAG="
if not defined T3P_NO_POWERSHELL for /f %%t in ('%PS% -NoProfile -NonInteractive -Command "$r = Invoke-RestMethod $env:T3P_URL -UseBasicParsing; $r | Where-Object { $_.tag_name -match $env:T3P_TAG_REGEX } | Select-Object -First 1 -ExpandProperty tag_name" 2^>nul') do set "TAG=%%t"
if defined TAG goto :t3_download
call :curl "%T3P_URL%" "%WORK%\t3-releases.json" || exit /b 1
set "PATTERN=tag_name.: .v[0-9]*\.[0-9]*\.[0-9]*-%T3CODE_CHANNEL%\."
if /i "%T3CODE_CHANNEL%"=="stable" set "PATTERN=tag_name.: .v[0-9]*\.[0-9]*\.[0-9]*.,"
for /f "tokens=2 delims=: " %%t in ('findstr /r /c:"%PATTERN%" "%WORK%\t3-releases.json"') do if not defined TAG set "TAG=%%t"
if not defined TAG (
  echo Could not find a %T3CODE_CHANNEL% release of T3 Code.
  exit /b 1
)
set "TAG=%TAG:"=%"
set "TAG=%TAG:,=%"
:t3_download
set "VER=%TAG:~1%"
if exist "%VERSIONS%\%VER%\.install-complete" exit /b 0
set "ZIP=t3-%VER%-win32-%ARCH%.zip"
set "URL=https://github.com/pingdotgg/t3code/releases/download/%TAG%"
set "STAGE=%VERSIONS%\.staging-portable"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%"
echo Downloading T3 Code %VER%...
call :fetch "%URL%/SHA256SUMS" "%STAGE%\SHA256SUMS" || exit /b 1
set "SUM="
for /f "tokens=1,2" %%a in ('findstr /c:"%ZIP%" "%STAGE%\SHA256SUMS"') do if "%%b"=="%ZIP%" set "SUM=%%a"
call :fetch "%URL%/%ZIP%" "%STAGE%\%ZIP%" || exit /b 1
call :verify "%STAGE%\%ZIP%" %SUM% || exit /b 1
"%SystemRoot%\System32\tar.exe" -xf "%STAGE%\%ZIP%" -C "%STAGE%" --strip-components=1 || exit /b 1
del "%STAGE%\%ZIP%" "%STAGE%\SHA256SUMS"
"%STAGE%\t3.exe" --version >nul
if errorlevel 1 (
  echo The downloaded T3 Code would not run. If this computer only allows approved
  echo programs, see "If programs are blocked" in README.md.
  exit /b 1
)
> "%STAGE%\.install-complete" echo %VER%
if exist "%VERSIONS%\%VER%" rmdir /s /q "%VERSIONS%\%VER%"
move "%STAGE%" "%VERSIONS%\%VER%" >nul
exit /b

:claude
rem install: download Claude Code if it is missing.
rem update: stage a newer version as claude.exe.new, swapped in at the next start
rem (Windows will not replace claude.exe while T3 is using it).
set "CLAUDE=%ROOT%\bin\claude.exe"
set "TARGET=%CLAUDE%"
if "%~1"=="install" if exist "%CLAUDE%" exit /b 0
if "%~1"=="update" (
  if not exist "%CLAUDE%" exit /b 0
  if exist "%CLAUDE%.new" exit /b 0
  set "TARGET=%CLAUDE%.new"
)
set "BASE=https://downloads.claude.ai/claude-code-releases"
call :fetch "%BASE%/latest" "%WORK%\claude-latest" || exit /b 1
set "LATEST="
set /p LATEST=<"%WORK%\claude-latest"
echo(%LATEST%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul || (
  echo downloads.claude.ai sent an unexpected reply. Claude Code may not be available in this region.
  exit /b 1
)
if "%~1"=="update" for /f "tokens=1" %%v in ('"%CLAUDE%" --version') do if "%%v"=="%LATEST%" exit /b 0
call :fetch "%BASE%/%LATEST%/manifest.json" "%WORK%\claude-manifest.json" || exit /b 1
set "SUM="
set "SIZE="
set "SECTION="
for /f "usebackq tokens=1,2 delims=:, " %%a in ("%WORK%\claude-manifest.json") do (
  if "%%~a"=="win32-%ARCH%" set "SECTION=1"
  if defined SECTION if not defined SUM if "%%~a"=="checksum" set "SUM=%%~b"
  if defined SECTION if not defined SIZE if "%%~a"=="size" set "SIZE=%%~b"
)
set /a SIZE_MB=SIZE/1048576
echo Downloading Claude Code %LATEST% (%SIZE_MB% MB)...
call :fetch "%BASE%/%LATEST%/win32-%ARCH%/claude.exe" "%WORK%\claude.exe" || exit /b 1
call :verify "%WORK%\claude.exe" %SUM% || exit /b 1
move /y "%WORK%\claude.exe" "%TARGET%" >nul
exit /b

:git
where git >nul 2>&1 && exit /b 0
if exist "%ROOT%\tools\git\cmd\git.exe" exit /b 0
echo Downloading Git...
call :fetch "%GIT_URL%" "%WORK%\PortableGit.7z.exe" || exit /b 1
call :verify "%WORK%\PortableGit.7z.exe" %GIT_SHA256% || exit /b 1
rem PortableGit unpacks itself silently; Windows' tar cannot read its archive format.
if exist "%ROOT%\tools\git.partial" rmdir /s /q "%ROOT%\tools\git.partial"
"%WORK%\PortableGit.7z.exe" -y -o"%ROOT%\tools\git.partial" >nul || exit /b 1
if not exist "%ROOT%\tools\git.partial\cmd\git.exe" exit /b 1
move "%ROOT%\tools\git.partial" "%ROOT%\tools\git" >nul
del "%WORK%\PortableGit.7z.exe"
exit /b

:fetch
rem Downloads %1 to %2. PowerShell follows the computer's proxy settings; curl's
rem retry relaxes certificate revocation checks, which some school networks block.
if not defined T3P_NO_POWERSHELL (
  set "T3P_URL=%~1"
  set "T3P_OUT=%~2"
  "%PS%" -NoProfile -NonInteractive -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest $env:T3P_URL -OutFile $env:T3P_OUT -UseBasicParsing" && exit /b 0
)
:curl
%CURL% -o "%~2" "%~1" && exit /b 0
%CURL% --ssl-revoke-best-effort -o "%~2" "%~1"
exit /b

:verify
rem Checks file %1 against SHA-256 %2 and deletes it on a mismatch.
set "ACTUAL="
set "T3P_FILE=%~1"
if not defined T3P_NO_POWERSHELL for /f %%h in ('%PS% -NoProfile -NonInteractive -Command "$h = Get-FileHash -LiteralPath $env:T3P_FILE -Algorithm SHA256; $h.Hash" 2^>nul') do set "ACTUAL=%%h"
if not defined ACTUAL for /f "skip=1 delims=" %%h in ('certutil -hashfile "%~1" SHA256') do if not defined ACTUAL set "ACTUAL=%%h"
if defined ACTUAL set "ACTUAL=%ACTUAL: =%"
if not "%~2"=="" if /i "%ACTUAL%"=="%~2" exit /b 0
echo %~nx1 did not match its published checksum, so it was not used.
del "%~1" 2>nul
exit /b 1
