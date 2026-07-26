@echo off
wpeinit

if exist X:\Deploy\bootstrap.cmd (
    call X:\Deploy\bootstrap.cmd
    exit /b %errorlevel%
)

echo.
echo ERROR: X:\Deploy\bootstrap.cmd was not found.
echo The Deploy directory must be embedded in boot.wim.
echo.
pause
exit /b 1
