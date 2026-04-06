@echo off
setlocal enabledelayedexpansion

title Axios Attack Scanner
color 0B

echo.
echo  ==========================================================
echo  ^|                                                        ^|
echo  ^|   AXIOS SUPPLY CHAIN ATTACK SCANNER                    ^|
echo  ^|                                                        ^|
echo  ^|   This will check if your computer was affected by     ^|
echo  ^|   the axios npm package hack (March 31, 2026).         ^|
echo  ^|                                                        ^|
echo  ^|   You do NOT need Node.js or npm installed.            ^|
echo  ^|   This works on any Windows computer.                  ^|
echo  ^|                                                        ^|
echo  ^|   This is SAFE to run. It only reads your files.       ^|
echo  ^|   Nothing on your computer will be changed.            ^|
echo  ^|                                                        ^|
echo  ==========================================================
echo.

REM --- Check PowerShell exists ---
where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo  [ERROR] PowerShell was not found on this computer.
    echo  This scanner requires PowerShell to run.
    echo  PowerShell comes pre-installed on Windows 7 and later.
    echo.
    echo  If you are on an older version of Windows, please
    echo  update to at least Windows 10.
    echo.
    goto :end
)

REM --- Check scanner script exists ---
if not exist "%~dp0axios-scanner.ps1" (
    color 0C
    echo  [ERROR] Cannot find axios-scanner.ps1
    echo.
    echo  Make sure SCAN.bat and axios-scanner.ps1 are in
    echo  the SAME folder. Do not move one without the other.
    echo.
    goto :end
)

echo  Starting scan... this may take a few minutes.
echo  You will see results appear below as each check runs.
echo.
echo  --------------------------------------------------------
echo.

REM --- Run the scanner ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0axios-scanner.ps1"
set SCAN_RESULT=%ERRORLEVEL%

echo.

if %SCAN_RESULT% EQU 1 (
    color 0C
    echo  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo  !!                                                    !!
    echo  !!   WARNING: YOUR COMPUTER MAY BE COMPROMISED        !!
    echo  !!                                                    !!
    echo  !!   A report file will open automatically.           !!
    echo  !!   Follow the instructions inside.                  !!
    echo  !!                                                    !!
    echo  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
) else (
    color 0A
    echo  ==========================================================
    echo  ^|                                                        ^|
    echo  ^|   ALL CLEAR - Your computer is safe.                   ^|
    echo  ^|                                                        ^|
    echo  ^|   A report will open automatically so you can          ^|
    echo  ^|   save or share it.                                    ^|
    echo  ^|                                                        ^|
    echo  ==========================================================
)

echo.

REM --- Auto-open the most recent report file ---
for /f "delims=" %%F in ('dir /b /o-d "%~dp0axios-scan-report_*.txt" 2^>nul') do (
    echo  Opening report: %%F
    start "" notepad "%~dp0%%F"
    goto :afteropen
)
:afteropen

echo.

:end
echo  Press any key to close this window...
pause >nul
