@echo off
setlocal

:: === Configuration ===
set "GIT_BASH_EXE=C:\Program Files\Git\bin\bash.exe"
set "GIT_INSTALLER=GitInstaller.exe"
set "DOWNLOAD_URL=https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe"
set "BASH_SCRIPT=check_script.sh"
set "LOG_FILE=%CD%\system_check.log"

:: === Logging function ===
echo ---------------------------------------- >> "%LOG_FILE%"
echo [%DATE% %TIME%] Script started >> "%LOG_FILE%"

:: === Check if Git Bash is installed ===
if exist "%GIT_BASH_EXE%" (
    echo Git Bash is already installed at: %GIT_BASH_EXE%
    echo [%DATE% %TIME%] Git Bash already installed >> "%LOG_FILE%"
    goto :RunScript
)

echo Git Bash not found. Downloading...
echo [%DATE% %TIME%] Git Bash not found. Starting download... >> "%LOG_FILE%"

:: === Check if curl is available ===
where curl >nul 2>&1
if errorlevel 1 (
    echo curl not found. Cannot proceed with download.
    echo [%DATE% %TIME%] curl not available. Exiting. >> "%LOG_FILE%"
    exit /b 1
)

:: === Download using curl ===
curl -L -o "%CD%\%GIT_INSTALLER%" "%DOWNLOAD_URL%" >> "%LOG_FILE%" 2>&1
if not exist "%CD%\%GIT_INSTALLER%" (
    echo Failed to download Git Bash installer.
    echo [%DATE% %TIME%] Download failed. Exiting. >> "%LOG_FILE%"
    exit /b 1
)

:: === Install Git Bash silently ===
echo Installing Git Bash...
echo [%DATE% %TIME%] Installing Git Bash... >> "%LOG_FILE%"
"%CD%\%GIT_INSTALLER%" /VERYSILENT /NORESTART >> "%LOG_FILE%" 2>&1

:: === Wait for installation ===
timeout /t 20 >nul

:: === Check again if Git Bash was installed ===
if not exist "%GIT_BASH_EXE%" (
    echo Git Bash was not installed correctly.
    echo [%DATE% %TIME%] Git Bash installation failed. >> "%LOG_FILE%"
    exit /b 1
)

:: === Run the bash script (no logging from CMD) ===
:RunScript
echo Running bash script with Git Bash...
echo [%DATE% %TIME%] Running bash script: %BASH_SCRIPT% >> "%LOG_FILE%"
"%GIT_BASH_EXE%" "%CD%\%BASH_SCRIPT%" 2>nul

echo [%DATE% %TIME%] Script finished >> "%LOG_FILE%"
endlocal
