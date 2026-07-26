#!/usr/bin/env bash
set -Eeuo pipefail

SAMBA_USER="${SAMBA_USER:-deploy}"
SAMBA_PASSWORD_FILE="${SAMBA_PASSWORD_FILE:-/run/secrets/samba_password}"

[[ "$SAMBA_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || {
    echo "Invalid SAMBA_USER: $SAMBA_USER" >&2
    exit 1
}

[[ -s "$SAMBA_PASSWORD_FILE" ]] || {
    echo "Password secret is missing or empty: $SAMBA_PASSWORD_FILE" >&2
    exit 1
}

# tmpfs mount points start empty on every container start.
mkdir -p \
    /var/lib/samba/private \
    /var/lib/samba/lock \
    /var/cache/samba \
    /var/log/samba \
    /run/samba

chmod 0700 /var/lib/samba/private
chmod 0755 \
    /var/lib/samba \
    /var/lib/samba/lock \
    /var/cache/samba \
    /var/log/samba \
    /run/samba

if ! getent passwd "$SAMBA_USER" >/dev/null; then
    useradd \
        --system \
        --no-create-home \
        --shell /usr/sbin/nologin \
        "$SAMBA_USER"
fi

password="$(cat "$SAMBA_PASSWORD_FILE")"

printf '%s\n%s\n' "$password" "$password" |
    smbpasswd -s -a "$SAMBA_USER"

unset password

testparm -s /etc/samba/smb.conf >/dev/null

exec smbd \
    --foreground \
    --no-process-group \
    --debug-stdout