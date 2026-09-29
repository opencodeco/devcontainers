#!/usr/bin/env bash
# Host-side checks for the install-php-extensions feature.
# Does not build a dev container and does not install packages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT}/features/install-php-extensions/install.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

assert_eq "$(debian_php_package zip)" "php-zip" "zip package"
assert_eq "$(debian_php_package pdo_mysql)" "php-mysql" "pdo_mysql package"
assert_eq "$(debian_php_package PDO_PGSQL)" "php-pgsql" "pdo_pgsql package"

mapfile -t zip_packages < <(debian_packages_for_extensions zip)
assert_eq "${zip_packages[0]}" "php-cli" "apt installs php-cli"
assert_eq "${zip_packages[1]}" "php-zip" "apt installs php-zip"
assert_eq "${#zip_packages[@]}" "2" "zip package count"

mapfile -t parsed < <(parse_extensions "zip, gd")
assert_eq "${parsed[0]}" "zip" "comma list first"
assert_eq "${parsed[1]}" "gd" "comma list second"
assert_eq "${#parsed[@]}" "2" "comma list count"

mapfile -t parsed_spaces < <(parse_extensions "zip gd")
assert_eq "${parsed_spaces[0]}" "zip" "space list first"
assert_eq "${parsed_spaces[1]}" "gd" "space list second"

mapfile -t parsed_empty < <(parse_extensions "")
assert_eq "${#parsed_empty[@]}" "0" "empty extension list"

tmp="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp}"
}
trap cleanup EXIT

printf 'ID=debian\n' > "${tmp}/debian"
OS_RELEASE="${tmp}/debian" is_debian_like || fail "debian os-release should match"
printf 'ID="ubuntu"\nID_LIKE=debian\n' > "${tmp}/ubuntu"
OS_RELEASE="${tmp}/ubuntu" is_debian_like || fail "ubuntu os-release should match"
printf 'ID=alpine\n' > "${tmp}/alpine"
if OS_RELEASE="${tmp}/alpine" is_debian_like; then
  fail "alpine os-release should not match"
fi

for cmd in docker-php-ext-configure docker-php-ext-enable docker-php-ext-install docker-php-source; do
  printf '#!/bin/sh\nexit 0\n' > "${tmp}/${cmd}"
  chmod +x "${tmp}/${cmd}"
done

saved_path="${PATH}"
PATH="${tmp}:/usr/bin:/bin"
has_official_php_helpers || fail "all four helpers should count as an official PHP image"
rm -f "${tmp}/docker-php-source"
if has_official_php_helpers; then
  fail "a missing docker-php-source should not count as an official PHP image"
fi
PATH="${saved_path}"

# Keep these overrides in place so a routing bug cannot apt-get or curl on the host.
called=""
install_with_mlocati() { called="mlocati:$*"; }
install_with_apt() { called="apt:$*"; }

EXTENSIONS="zip"
has_official_php_helpers() { return 0; }
is_debian_like() { return 0; }
main
assert_eq "${called}" "mlocati:zip" "official image uses mlocati"

called=""
has_official_php_helpers() { return 1; }
is_debian_like() { return 0; }
if ! command -v apt-get >/dev/null 2>&1; then
  fail "this check expects apt-get on PATH so the Debian branch can be selected"
fi
main
assert_eq "${called}" "apt:zip" "Debian base uses apt for zip"

called=""
has_official_php_helpers() { return 1; }
is_debian_like() { return 0; }
mkdir -p "${tmp}/limited-path"
ln -s "$(command -v cat)" "${tmp}/limited-path/cat"
# This assignment is the search path on purpose. It only contains cat, so apt-get is absent.
# shellcheck disable=SC2123
PATH="${tmp}/limited-path"
set +e
unsupported_out="$(EXTENSIONS="zip" main 2>&1)"
unsupported_rc=$?
set -e
PATH="${saved_path}"
if [[ "${unsupported_rc}" -eq 0 ]]; then
  fail "debian-like image without apt-get should fail"
fi
if [[ "${unsupported_out}" != *"mlocati/docker-php-extension-installer was not downloaded or run"* ]]; then
  fail "unsupported base should explain that the upstream script was not run: ${unsupported_out}"
fi
if [[ "${unsupported_out}" != *"mcr.microsoft.com/devcontainers/base"* ]]; then
  fail "unsupported base should name the devcontainers base image: ${unsupported_out}"
fi
assert_eq "${called}" "" "unsupported base should not call an installer"

called=""
has_official_php_helpers() { return 1; }
is_debian_like() { return 1; }
set +e
alpine_out="$(EXTENSIONS="zip" main 2>&1)"
alpine_rc=$?
set -e
if [[ "${alpine_rc}" -eq 0 ]]; then
  fail "non-Debian image without PHP helpers should fail"
fi
if [[ "${alpine_out}" != *"meant to be used with official Docker PHP Images"* ]]; then
  fail "failure should quote the upstream error before that script runs: ${alpine_out}"
fi
assert_eq "${called}" "" "non-Debian base should not call an installer"

set +e
invalid_out="$(EXTENSIONS='zip;rm' main 2>&1)"
invalid_rc=$?
set -e
if [[ "${invalid_rc}" -eq 0 ]]; then
  fail "invalid extension names should fail"
fi
if [[ "${invalid_out}" != *"invalid extension name"* ]]; then
  fail "invalid extension should be rejected: ${invalid_out}"
fi

echo "ok"
