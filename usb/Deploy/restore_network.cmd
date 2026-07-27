@echo off
setlocal EnableExtensions EnableDelayedExpansion
title WinPE Network WIM Restore

set "RUNTIME_DIR=%~dp0"
call "%RUNTIME_DIR%deploy.conf.cmd"

if not defined DEPLOY_SERVER goto :config_error
if not defined DEPLOY_SHARE goto :config_error
if not defined DEPLOY_USER goto :config_error
if not defined DEPLOY_PASSWORD goto :config_error
if not defined DEPLOY_DRIVE set "DEPLOY_DRIVE=Z:"
if not defined IMAGE_SUBDIR set "IMAGE_SUBDIR=images"
if not defined WIM_INDEX set "WIM_INDEX=1"

set "SHARE_PATH=\\%DEPLOY_SERVER%\%DEPLOY_SHARE%"
set "IMAGE_ROOT=%DEPLOY_DRIVE%\%IMAGE_SUBDIR%"
set "DP_LIST=X:\wim-deploy-list.txt"
set "DP_PART=X:\wim-deploy-partition.txt"

call :header
call :initialize_network || goto :fatal
call :connect_share || goto :fatal
call :select_image || goto :fatal
call :select_target_disk || goto :fatal
call :detect_firmware || goto :fatal
call :confirm_erase || goto :cancelled
call :partition_disk || goto :fatal
call :apply_image || goto :fatal
call :create_boot_files || goto :fatal

echo.
echo ============================================================
echo RESTORE COMPLETED SUCCESSFULLY
echo ============================================================
echo.
echo Remove the USB drive if it is still connected.
echo Press any key to reboot into the restored operating system.
pause >nul

net use "%DEPLOY_DRIVE%" /delete /y >nul 2>&1
wpeutil reboot
exit /b 0

:header
echo.
echo ============================================================
echo NETWORK WIM RESTORE
echo ============================================================
echo Server : %SHARE_PATH%
echo Images : %IMAGE_ROOT%
echo Runtime: %RUNTIME_DIR%
echo.
exit /b 0

:initialize_network
echo Initializing WinPE networking...
wpeinit >nul 2>&1

echo Current network configuration:
ipconfig
echo.
exit /b 0

:connect_share
echo.
echo Connecting to %SHARE_PATH%...

set /a SMB_TRIES=0

:connect_share_retry
set /a SMB_TRIES+=1
net use "%DEPLOY_DRIVE%" /delete /y >nul 2>&1
net use "%DEPLOY_DRIVE%" "%SHARE_PATH%" ^
    /user:"%DEPLOY_USER%" "%DEPLOY_PASSWORD%" /persistent:no >nul 2>&1

if not errorlevel 1 (
    if exist "%IMAGE_ROOT%\\" (
        echo Connected successfully.
        exit /b 0
    )
)

if !SMB_TRIES! geq 12 (
    echo ERROR: Failed to connect to %SHARE_PATH% after !SMB_TRIES! attempts.
    echo Check DHCP, server IP, Samba account, password, firewall, and network driver.
    exit /b 1
)

echo SMB is not ready. Retrying !SMB_TRIES!/12...
rem WinPE may not include timeout.exe. ping provides a portable delay.
ping 127.0.0.1 -n 6 >nul 2>&1
goto :connect_share_retry

:select_image
echo.
echo Available WIM images:
echo ------------------------------------------------------------

set /a IMAGE_COUNT=0
for /f "delims=" %%F in ('dir /b /a-d "%IMAGE_ROOT%\*.wim" 2^>nul') do (
    set /a IMAGE_COUNT+=1
    set "IMAGE_!IMAGE_COUNT!=%%F"
    echo   [!IMAGE_COUNT!] %%F
)

echo ------------------------------------------------------------

if !IMAGE_COUNT! equ 0 (
    echo ERROR: No WIM files were found in %IMAGE_ROOT%.
    exit /b 1
)

:select_image_retry
set "IMAGE_CHOICE="
set /p "IMAGE_CHOICE=Select image number: "

call :is_positive_integer "%IMAGE_CHOICE%"
if errorlevel 1 (
    echo Invalid selection.
    goto :select_image_retry
)

if %IMAGE_CHOICE% gtr %IMAGE_COUNT% (
    echo Invalid selection.
    goto :select_image_retry
)

for %%N in (%IMAGE_CHOICE%) do set "WIM_NAME=!IMAGE_%%N!"
set "WIM_PATH=%IMAGE_ROOT%\%WIM_NAME%"

if not exist "%WIM_PATH%" (
    echo ERROR: Selected WIM is no longer available.
    exit /b 1
)

echo.
echo Selected image:
echo   %WIM_PATH%
echo.

dism /Get-WimInfo /WimFile:"%WIM_PATH%" /Index:%WIM_INDEX%
if errorlevel 1 (
    echo ERROR: DISM could not read the selected WIM or index.
    exit /b 1
)

exit /b 0

:select_target_disk
echo.
echo Current disks:
echo ------------------------------------------------------------
(
    echo list disk
    echo exit
) > "%DP_LIST%"

diskpart /s "%DP_LIST%"
if errorlevel 1 (
    echo ERROR: DiskPart could not enumerate disks.
    exit /b 1
)
echo ------------------------------------------------------------

:target_retry
set "TARGET_DISK="
set /p "TARGET_DISK=Enter TARGET disk number: "

call :is_nonnegative_integer "%TARGET_DISK%"
if errorlevel 1 (
    echo Invalid disk number.
    goto :target_retry
)

(
    echo select disk %TARGET_DISK%
    echo detail disk
    echo exit
) > "%DP_LIST%"

diskpart /s "%DP_LIST%"
if errorlevel 1 (
    echo Invalid or unavailable target disk.
    goto :target_retry
)

exit /b 0

:detect_firmware
set "FIRMWARE=UEFI"

for /f "tokens=3" %%A in (
    'reg query HKLM\SYSTEM\CurrentControlSet\Control /v PEFirmwareType 2^>nul ^| find "PEFirmwareType"'
) do set "PE_FIRMWARE_TYPE=%%A"

if /I "%PE_FIRMWARE_TYPE%"=="0x1" set "FIRMWARE=BIOS"
if /I "%PE_FIRMWARE_TYPE%"=="0x2" set "FIRMWARE=UEFI"

echo.
echo Firmware detected: %FIRMWARE%
exit /b 0

:confirm_erase
echo.
echo ============================================================
echo DESTRUCTIVE OPERATION
echo ============================================================
echo Image      : %WIM_NAME%
echo WIM index  : %WIM_INDEX%
echo Target disk: %TARGET_DISK%
echo Firmware   : %FIRMWARE%
echo.
echo Disk %TARGET_DISK% will be COMPLETELY ERASED.
echo.

set "EXPECTED_CONFIRM=ERASE-DISK-%TARGET_DISK%"
set "CONFIRM="
set /p "CONFIRM=Type %EXPECTED_CONFIRM% to continue: "

if /I not "%CONFIRM%"=="%EXPECTED_CONFIRM%" exit /b 1
exit /b 0

:partition_disk
echo.
echo Partitioning disk %TARGET_DISK%...

(
    echo select disk %TARGET_DISK%
    echo clean
) > "%DP_PART%"

if /I "%FIRMWARE%"=="BIOS" (
    (
        echo convert mbr
        echo create partition primary
        echo format fs=ntfs quick label=Windows
        echo assign letter=W
        echo active
    ) >> "%DP_PART%"
) else (
    (
        echo convert gpt
        echo create partition efi size=260
        echo format fs=fat32 quick label=System
        echo assign letter=S
        echo create partition msr size=16
        echo create partition primary
        echo format fs=ntfs quick label=Windows
        echo assign letter=W
    ) >> "%DP_PART%"
)

echo exit >> "%DP_PART%"

diskpart /s "%DP_PART%"
if errorlevel 1 (
    echo ERROR: Disk partitioning failed.
    exit /b 1
)

if not exist W:\ (
    echo ERROR: Windows target volume W: was not created.
    exit /b 1
)

if /I "%FIRMWARE%"=="UEFI" if not exist S:\ (
    echo ERROR: EFI System Partition S: was not created.
    exit /b 1
)

exit /b 0

:apply_image
echo.
echo ============================================================
echo READY TO START NETWORK IMAGE TRANSFER
echo ============================================================
echo WinPE and all deployment scripts are running from RAM.
echo The WIM will be read only from the network server.
echo.
echo Once DISM displays progress, the USB drive may be removed.
echo Do not disconnect power, Ethernet, or the deployment server.
echo ============================================================
echo.

rem WinPE may not include timeout.exe.
ping 127.0.0.1 -n 4 >nul 2>&1

dism /Apply-Image ^
    /ImageFile:"%WIM_PATH%" ^
    /Index:%WIM_INDEX% ^
    /ApplyDir:W:\

if errorlevel 1 (
    echo.
    echo ERROR: DISM image application failed.
    echo Keep the USB disconnected only if it was removed after progress began;
    echo the failure is normally related to network, server, WIM, or disk I/O.
    exit /b 1
)

exit /b 0

:create_boot_files
echo.
echo Creating Windows boot files...

if /I "%FIRMWARE%"=="BIOS" (
    bcdboot W:\Windows /s W: /f BIOS
) else (
    bcdboot W:\Windows /s S: /f UEFI
)

if errorlevel 1 (
    echo ERROR: BCDBOOT failed.
    exit /b 1
)

exit /b 0

:is_positive_integer
set "VALUE=%~1"
if not defined VALUE exit /b 1
for /f "delims=0123456789" %%A in ("%VALUE%") do exit /b 1
if %VALUE% leq 0 exit /b 1
exit /b 0

:is_nonnegative_integer
set "VALUE=%~1"
if not defined VALUE exit /b 1
for /f "delims=0123456789" %%A in ("%VALUE%") do exit /b 1
exit /b 0

:config_error
echo.
echo ERROR: Deployment configuration is incomplete.
echo Edit: %RUNTIME_DIR%deploy.conf.cmd
goto :fatal

:cancelled
echo.
echo Restore cancelled. No image was applied.
net use "%DEPLOY_DRIVE%" /delete /y >nul 2>&1
pause
exit /b 2

:fatal
echo.
echo ============================================================
echo DEPLOYMENT FAILED
echo ============================================================
echo Review the error above.
echo.
net use "%DEPLOY_DRIVE%" /delete /y >nul 2>&1
pause
exit /b 1
