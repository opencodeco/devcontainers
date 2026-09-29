#!/usr/bin/env bash
# Install PHP extensions for a dev container feature.
#
# Official Docker PHP images provide docker-php-ext-install and related
# helpers. On those images this script runs mlocati/docker-php-extension-installer.
# Debian and Ubuntu images, including mcr.microsoft.com/devcontainers/base,
# do not provide those helpers. On those images this script installs php-cli
# and the distro package for each extension. zip becomes php-zip.
# It does not create fake helper commands to look like an official PHP image.
set -euo pipefail

MLOCATI_VERSION="2.2.5"
MLOCATI_URL="https://github.com/mlocati/docker-php-extension-installer/releases/download/${MLOCATI_VERSION}/install-php-extensions"

has_official_php_helpers() {
  command -v docker-php-ext-configure >/dev/null 2>&1 \
    && command -v docker-php-ext-enable >/dev/null 2>&1 \
    && command -v docker-php-ext-install >/dev/null 2>&1 \
    && command -v docker-php-source >/dev/null 2>&1
}

is_debian_like() {
  local os_release="${OS_RELEASE:-/etc/os-release}"
  local detected

  [[ -r "${os_release}" ]] || return 1
  detected="$(
    # shellcheck disable=SC1090
    . "${os_release}"
    printf '%s' " ${ID:-} ${ID_LIKE:-} "
  )"
  case "${detected}" in
    *" debian "*|*" ubuntu "*) return 0 ;;
    *) return 1 ;;
  esac
}

parse_extensions() {
  local raw="${1:-}"
  local -a parts=()
  local ext

  raw="${raw//,/ }"
  # An empty value makes read return 1. That is an empty list, not a failure.
  read -ra parts <<< "${raw}" || true
  for ext in "${parts[@]}"; do
    if [[ -n "${ext}" ]]; then
      printf '%s\n' "${ext}"
    fi
  done
}

validate_extension_name() {
  local ext="$1"

  if [[ ! "${ext}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    echo "install-php-extensions: invalid extension name '${ext}'. Use letters, digits, underscores, or hyphens." >&2
    exit 1
  fi
}

debian_php_package() {
  local ext="${1,,}"

  case "${ext}" in
    pdo_mysql|mysqli|mysqlnd) printf '%s\n' php-mysql ;;
    pdo_pgsql|pgsql) printf '%s\n' php-pgsql ;;
    pdo_sqlite|sqlite|sqlite3) printf '%s\n' php-sqlite3 ;;
    *) printf 'php-%s\n' "${ext}" ;;
  esac
}

debian_packages_for_extensions() {
  local ext

  printf '%s\n' php-cli
  for ext in "$@"; do
    debian_php_package "${ext}"
  done
}

install_with_mlocati() {
  local -a exts=("$@")

  curl -sSLf -o /usr/local/bin/install-php-extensions "${MLOCATI_URL}"
  chmod +x /usr/local/bin/install-php-extensions
  if ((${#exts[@]} == 0)); then
    install-php-extensions
  else
    install-php-extensions "${exts[@]}"
  fi
}

install_with_apt() {
  local -a exts=("$@")
  local -a packages=()
  local pkg

  if ((${#exts[@]} == 0)); then
    echo "install-php-extensions: no extensions listed, so no packages were installed." >&2
    return 0
  fi

  while IFS= read -r pkg; do
    packages+=("${pkg}")
  done < <(debian_packages_for_extensions "${exts[@]}")

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends "${packages[@]}"
  rm -rf /var/lib/apt/lists/*
}

fail_unsupported_base() {
  cat >&2 <<'EOF'
install-php-extensions: this image cannot install PHP extensions.

Supported bases:
- Official Docker PHP images from https://hub.docker.com/_/php. Those images provide docker-php-ext-install, docker-php-ext-configure, docker-php-ext-enable, and docker-php-source. This feature then runs mlocati/docker-php-extension-installer.
- Debian and Ubuntu images, including mcr.microsoft.com/devcontainers/base. Those images install each extension with apt. The zip extension installs the php-zip package, and php-cli is installed with it.

This image has neither those official PHP helper commands nor apt on Debian or Ubuntu. mlocati/docker-php-extension-installer was not downloaded or run. That script only works on official PHP images and exits with the message "meant to be used with official Docker PHP Images".
EOF
  exit 1
}

main() {
  local -a exts=()
  local ext

  while IFS= read -r ext; do
    [[ -n "${ext}" ]] || continue
    validate_extension_name "${ext}"
    exts+=("${ext}")
  done < <(parse_extensions "${EXTENSIONS:-}")

  if has_official_php_helpers; then
    install_with_mlocati "${exts[@]}"
    return
  fi

  if is_debian_like && command -v apt-get >/dev/null 2>&1; then
    install_with_apt "${exts[@]}"
    return
  fi

  fail_unsupported_base
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
