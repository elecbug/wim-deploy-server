# WIM Deploy WinPE USB

This package is the WinPE-side companion for the Docker Samba deployment server.

## Runtime flow

```text
USB boot
  -> WinPE loads into RAM drive X:
  -> startnet.cmd runs bootstrap.cmd
  -> bootstrap copies Deploy directory into X:\Deploy
  -> X:\Deploy\restore_network.cmd connects to SMB
  -> operator selects WIM and target disk
  -> target disk is partitioned
  -> DISM starts applying the WIM directly from SMB
  -> USB can be removed
  -> BCDBOOT creates boot files
  -> reboot
```

After `bootstrap.cmd` finishes copying to `X:\Deploy`, the USB is no longer used.
The deployment image remains on the SMB server and is streamed over the network.

## Files

```text
startnet.cmd
Deploy/
├── bootstrap.cmd
├── restore_network.cmd
└── deploy.conf.cmd
```

## Configuration

Edit `Deploy/deploy.conf.cmd`:

```bat
set "DEPLOY_SERVER=172.20.4.100"
set "DEPLOY_SHARE=deployment"
set "DEPLOY_USER=deploy"
set "DEPLOY_PASSWORD=CHANGE_ME"
```

The Samba account should be read-only and restricted to the campus/laboratory
network.

## Integrating into boot.wim

Mount the WinPE image and copy:

```text
startnet.cmd                  -> Windows\System32\startnet.cmd
Deploy\                       -> Deploy\
```

At runtime, the files will appear as:

```text
X:\Windows\System32\startnet.cmd
X:\Deploy\bootstrap.cmd
X:\Deploy\restore_network.cmd
X:\Deploy\deploy.conf.cmd
```

If the files are kept only in a visible USB partition instead of embedded into
boot.wim, change `startnet.cmd` to locate and call the USB's bootstrap script.
Embedding the files into boot.wim is recommended because it guarantees that the
USB can be removed immediately after WinPE has loaded.

## First test

Use a non-production PC and a disposable disk. Confirm that:

1. WinPE obtains an IP address.
2. `\\SERVER_IP\deployment` is reachable.
3. WIM files appear under `Z:\images`.
4. The correct target disk is selected.
5. DISM begins before removing the USB.
6. The restored Windows boots successfully.
