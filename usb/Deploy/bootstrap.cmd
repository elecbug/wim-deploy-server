@echo off
setlocal EnableExtensions

title WIM Deploy Bootstrap

set "RAM_ROOT=X:\DeployRuntime"

echo.
echo Preparing deployment runtime in RAM...

if exist "%RAM_ROOT%" rmdir /s /q "%RAM_ROOT%"
mkdir "%RAM_ROOT%" || goto :fail

xcopy X:\Deploy\* "%RAM_ROOT%\" /E /I /H /Y >nul
if errorlevel 1 goto :fail

if not exist "%RAM_ROOT%\restore_network.cmd" goto :fail
if not exist "%RAM_ROOT%\deploy.conf.cmd" goto :fail

echo Runtime copied to %RAM_ROOT%.
echo All scripts now execute from the WinPE RAM drive.
echo.

call "%RAM_ROOT%\restore_network.cmd"
exit /b %errorlevel%

:fail
echo.
echo ERROR: Failed to prepare the RAM-based deployment runtime.
pause
exit /b 1
