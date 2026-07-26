#!/usr/bin/env bash
set -Eeuo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

resolve_disks() {
    [[ -L disks ]] || die "'./disks' must be a symbolic link."
    local resolved
    resolved="$(readlink -f -- disks)" || die "Unable to resolve './disks'."
    [[ -d "$resolved" ]] || die "Resolved disks path is not a directory: $resolved"
    [[ -d "$resolved/images" ]] || die "Missing directory: $resolved/images"
    [[ -d "$resolved/scripts" ]] || die "Missing directory: $resolved/scripts"

    export DISKS_REALPATH="$resolved"
}

check_files() {
    [[ -f .env ]] || die "Missing .env. Copy .env.example to .env and edit it."
    [[ -s secrets/samba_password.txt ]] || die "Missing or empty secrets/samba_password.txt."
}

show_config() {
    printf 'Project directory : %s\n' "$PWD"
    printf 'disks link       : %s\n' "$(readlink -- disks)"
    printf 'resolved storage : %s\n' "$DISKS_REALPATH"
    docker compose config
}

resolve_disks
check_files

command="${1:-up}"
shift || true

case "$command" in
    up)
        docker compose up -d --build "$@"
        docker compose ps
        ;;
    down)
        docker compose down "$@"
        ;;
    restart)
        docker compose down
        docker compose up -d --build "$@"
        docker compose ps
        ;;
    logs)
        docker compose logs -f "$@"
        ;;
    ps)
        docker compose ps "$@"
        ;;
    config)
        show_config
        ;;
    test)
        server_ip="$(sed -n 's/^SERVER_IP=//p' .env | tail -n1)"
        user="$(sed -n 's/^SAMBA_USER=//p' .env | tail -n1)"
        password="$(cat secrets/samba_password.txt)"
        [[ -n "$server_ip" ]] || die "SERVER_IP is empty in .env."
        [[ -n "$user" ]] || user=deploy

        docker run --rm --network host \
          ubuntu:24.04 bash -ceu '
            apt-get update >/dev/null
            DEBIAN_FRONTEND=noninteractive apt-get install -y smbclient >/dev/null
            smbclient "//$1/deployment" -U "$2%$3" -m SMB3 -c "ls"
          ' -- "$server_ip" "$user" "$password"
        ;;
    *)
        die "Usage: $0 {up|down|restart|logs|ps|config|test}"
        ;;
esac
