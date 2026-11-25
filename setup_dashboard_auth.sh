#!/usr/bin/env bash
set -euo pipefail
umask 077

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
env_file="$root_dir/.env"

if ! command -v openssl >/dev/null 2>&1; then
  printf 'Error: openssl is required to set dashboard credentials.\n' >&2
  exit 1
fi

if [[ ! -f "$env_file" ]]; then
  cp "$root_dir/.env.example" "$env_file"
fi

read -r -p "Dashboard username: " username
if [[ ! "$username" =~ ^[a-zA-Z0-9._-]{1,128}$ ]]; then
  printf 'Error: use 1-128 letters, numbers, dots, underscores or hyphens for the username.\n' >&2
  exit 1
fi

read -r -s -p "Dashboard password (at least 12 characters): " password
printf '\n'
if (( ${#password} < 12 )); then
  unset password
  printf 'Error: choose a password with at least 12 characters.\n' >&2
  exit 1
fi
read -r -s -p "Confirm dashboard password: " password_confirmation
printf '\n'
if [[ "$password" != "$password_confirmation" ]]; then
  unset password password_confirmation
  printf 'Error: passwords do not match.\n' >&2
  exit 1
fi
unset password_confirmation

salt="$(openssl rand -hex 16)"
password_hash="$(printf '%s\n' "$password" | openssl passwd -6 -salt "rounds=500000\$$salt" -stdin)"
unset password
secret_key="$(openssl rand -hex 32)"

tmp_file="$(mktemp "$root_dir/.env.XXXXXX")"
trap 'rm -f -- "$tmp_file"' EXIT

username_written=false
hash_written=false
secret_written=false
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    WEB_DASHBOARD_USERNAME=*)
      if [[ "$username_written" == false ]]; then
        printf "WEB_DASHBOARD_USERNAME='%s'\n" "$username" >> "$tmp_file"
        username_written=true
      fi
      ;;
    WEB_DASHBOARD_PASSWORD_HASH=*)
      if [[ "$hash_written" == false ]]; then
        printf "WEB_DASHBOARD_PASSWORD_HASH='%s'\n" "$password_hash" >> "$tmp_file"
        hash_written=true
      fi
      ;;
    WEB_DASHBOARD_SECRET_KEY=*)
      if [[ "$secret_written" == false ]]; then
        printf "WEB_DASHBOARD_SECRET_KEY='%s'\n" "$secret_key" >> "$tmp_file"
        secret_written=true
      fi
      ;;
    *)
      printf '%s\n' "$line" >> "$tmp_file"
      ;;
  esac
done < "$env_file"

if [[ "$username_written" == false ]]; then
  printf "WEB_DASHBOARD_USERNAME='%s'\n" "$username" >> "$tmp_file"
fi
if [[ "$hash_written" == false ]]; then
  printf "WEB_DASHBOARD_PASSWORD_HASH='%s'\n" "$password_hash" >> "$tmp_file"
fi
if [[ "$secret_written" == false ]]; then
  printf "WEB_DASHBOARD_SECRET_KEY='%s'\n" "$secret_key" >> "$tmp_file"
fi

chmod 600 "$tmp_file"
mv -- "$tmp_file" "$env_file"
trap - EXIT

printf 'Dashboard credentials saved to .env (permissions 600).\n'
printf 'Restart the dashboard with: docker compose up -d --build\n'
