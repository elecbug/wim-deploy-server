# WIM Deployment SMB Server

A minimal Docker Compose service that exposes Windows deployment files over a
read-only SMB share to campus-network WinPE clients.

## Storage contract

The project directory must contain a symbolic link named `disks`.

Example:

```bash
sudo mkdir -p /mnt/deploy-disk/wim-deployment/{images,scripts,drivers}
ln -s /mnt/deploy-disk/wim-deployment disks
```

Expected layout:

```text
disks -> /mnt/deploy-disk/wim-deployment
├── images/
│   └── lab.wim
├── scripts/
│   └── restore_network.cmd
└── drivers/
```

`manage.sh` resolves the symbolic link with `readlink -f`, validates the target,
and exports the real host path to Docker Compose. The container receives it at
`/srv/deployment` as a read-only bind mount.

## Initial setup

```bash
cp .env.example .env
nano .env

mkdir -p secrets
openssl rand -base64 24 > secrets/samba_password.txt
chmod 600 secrets/samba_password.txt

chmod +x manage.sh samba/entrypoint.sh
./manage.sh config
./manage.sh up
```

Before starting, edit `samba/smb.conf` and narrow `hosts allow` to the actual
laboratory/campus subnet.

## Server-side test

```bash
./manage.sh test
```

## WinPE test

```bat
wpeinit
net use Z: \\SERVER_IP\deployment /user:deploy *
dir Z:\images
dism /Get-WimInfo /WimFile:Z:\images\lab.wim
```

Use `*` to request the password interactively during the first test.

## Operations

```bash
./manage.sh up
./manage.sh logs
./manage.sh ps
./manage.sh restart
./manage.sh down
```

## Image publication

Copy to a temporary filename first, then rename it so clients never see a
partially uploaded WIM:

```bash
sudo cp new-image.wim disks/images/new-image.wim.uploading
sudo mv disks/images/new-image.wim.uploading disks/images/new-image.wim
sha256sum disks/images/new-image.wim | sudo tee disks/images/new-image.wim.sha256
```
