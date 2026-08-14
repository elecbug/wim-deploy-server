dism /Mount-Image /ImageFile:E:\sources\boot.wim /Index:1 /MountDir:C:\WinPEMount

dism /Unmount-Image /MountDir:C:\WinPEMount /Commit

dism /Image:C:\WinPEMount /Add-Driver /Driver:C:\WinPEDrivers /Recurse