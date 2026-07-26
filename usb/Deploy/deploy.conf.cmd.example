@echo off

rem Campus-only deployment server settings.
set "DEPLOY_SERVER=172.20.4.100"
set "DEPLOY_SHARE=deployment"
set "DEPLOY_USER=deploy"

rem This password belongs to a read-only Samba account.
rem Restrict the account and TCP 445 to the laboratory/campus network.
set "DEPLOY_PASSWORD=CHANGE_ME"

rem Share layout:
rem   \\SERVER\deployment\images\*.wim
set "IMAGE_SUBDIR=images"

rem Preferred temporary SMB drive letter in WinPE.
set "DEPLOY_DRIVE=Z:"

rem WIM image index to apply.
set "WIM_INDEX=1"
