#!/usr/bin/env bash

# 

# init-marko.sh

# ––––––––––––––––––––––––––––––––––––––

# Devcontainer post-create init script for Marko.build projects.

# Fully non-interactive — driven by the config block below, with optional

# overrides from environment variables.

# 

# Behavior:

# 1. If Marko is already installed in the workspace: runs `composer install`

# and exits.

# 2. Otherwise scaffolds a new Marko project using the configured values,

# then composer-requires the selected optional packages.

# 

# Safe to run repeatedly. Designed for devcontainer.json’s “postCreateCommand”.

# ––––––––––––––––––––––––––––––––––––––

set -euo pipefail

# =============================================================================

# CONFIGURATION

# —————————————————————————–

# Each setting uses `${VAR:-default}` so environment variables override the

# defaults baked into the script. Edit the defaults here, or export the vars

# in devcontainer.json / your shell to override per-container.

# =============================================================================

# — Workspace —————————————————————

# Directory the project is scaffolded into (parent of the new project folder).

WORKSPACE_DIR=”${WORKSPACE_DIR:-${PWD}}”

# — Project —————————————————————–

# Name of the project directory created under WORKSPACE_DIR.

MARKO_PROJECT_NAME=”${MARKO_PROJECT_NAME:-my-app}”

# — Install mode ————————————————————

# “skeleton”  -> composer create-project marko/skeleton  (full app scaffold)

# “framework” -> composer init + composer require marko/framework (bare)

MARKO_INSTALL_MODE=”${MARKO_INSTALL_MODE:-skeleton}”

# — Optional packages —————————————————––

# Space-separated list of composer packages to `composer require` after the

# base install. Anything matching MARKO_DEV_PACKAGES_REGEX is installed with

# –dev. Set to “” to skip extras.

# 

# Available marko/* packages (as of writing):

# marko/database        Database layer (migrations, query builder, ORM)

# marko/cache-redis     Redis-backed cache driver

# marko/session         HTTP session handling

# marko/view            Templating / view layer

# marko/security        CSRF, CORS, security headers middleware

# marko/log             PSR-3 logging

# marko/webhook         Webhook sending

# marko/rate-limiting   Request rate limiting

# marko/testing         Pest integration, fakes, assertions  (dev)

# marko/dev-server      Local dev server                     (dev)

MARKO_PACKAGES=”${MARKO_PACKAGES:-marko/database marko/session marko/view marko/security marko/testing marko/dev-server}”

# Regex of packages that should be installed with –dev.

MARKO_DEV_PACKAGES_REGEX=”${MARKO_DEV_PACKAGES_REGEX:-^(marko/testing|marko/dev-server)$}”

# — Behavior flags –––––––––––––––––––––––––––––

# If “1”, overwrite the target directory if it exists and is non-empty.

MARKO_FORCE=”${MARKO_FORCE:-0}”

# If “1”, skip the PHP 8.5+ version check (useful for CI on older images).

MARKO_SKIP_PHP_CHECK=”${MARKO_SKIP_PHP_CHECK:-0}”

# Composer flags applied to all composer calls.

MARKO_COMPOSER_FLAGS=”${MARKO_COMPOSER_FLAGS:—no-interaction}”

# =============================================================================

# END CONFIGURATION — you shouldn’t need to edit below

# =============================================================================

# –– Pretty output –––––––––––––––––––––––––––––

C_RESET=”\033[0m”; C_BOLD=”\033[1m”; C_DIM=”\033[2m”
C_GREEN=”\033[32m”; C_YELLOW=”\033[33m”; C_BLUE=”\033[34m”; C_RED=”\033[31m”

info()  { printf “${C_BLUE}==>${C_RESET} %s\n” “$*”; }
ok()    { printf “${C_GREEN}\xe2\x9c\x93${C_RESET}  %s\n” “$*”; }
warn()  { printf “${C_YELLOW}!${C_RESET}  %s\n” “$*”; }
err()   { printf “${C_RED}\xe2\x9c\x97${C_RESET}  %s\n” “$*” >&2; }
hr()    { printf “${C_DIM}––––––––––––––––––––––––––––––––${C_RESET}\n”; }

# –– Prereq checks –––––––––––––––––––––––––––––

require_cmd() {
command -v “$1” >/dev/null 2>&1 || { err “Required command ‘$1’ not found in PATH.”; exit 1; }
}

check_prereqs() {
info “Checking prerequisites”
require_cmd php
require_cmd composer

local php_ver
php_ver=”$(php -r ‘echo PHP_VERSION;’)”
ok “PHP ${php_ver}”
ok “Composer $(composer –version –no-ansi 2>/dev/null | awk ‘{print $3}’)”

if [[ “${MARKO_SKIP_PHP_CHECK}” != “1” ]]; then
if ! php -r ‘exit(version_compare(PHP_VERSION, “8.5.0”, “>=”) ? 0 : 1);’; then
warn “Marko requires PHP 8.5+. Current PHP is ${php_ver}. Install may fail.”
warn “Set MARKO_SKIP_PHP_CHECK=1 to silence this warning.”
fi
fi
}

# –– Validation ———————————————————––

validate_config() {
if [[ ! “${MARKO_PROJECT_NAME}” =~ ^[a-zA-Z0-9_-]+$ ]]; then
err “Invalid MARKO_PROJECT_NAME ‘${MARKO_PROJECT_NAME}’. Allowed: a-z A-Z 0-9 _ -”
exit 1
fi

case “${MARKO_INSTALL_MODE}” in
skeleton|framework) ;;
*)
err “Invalid MARKO_INSTALL_MODE ‘${MARKO_INSTALL_MODE}’. Expected: skeleton | framework”
exit 1
;;
esac

if [[ ! -d “${WORKSPACE_DIR}” ]]; then
err “WORKSPACE_DIR ‘${WORKSPACE_DIR}’ does not exist.”
exit 1
fi
}

print_config() {
hr
printf “${C_BOLD}Marko.build devcontainer init${C_RESET}\n”
hr
echo “  Workspace    : ${WORKSPACE_DIR}”
echo “  Project name : ${MARKO_PROJECT_NAME}”
echo “  Install mode : marko/${MARKO_INSTALL_MODE}”
if [[ -n “${MARKO_PACKAGES// }” ]]; then
echo “  Extra pkgs   : ${MARKO_PACKAGES}”
else
echo “  Extra pkgs   : (none)”
fi
echo “  Force        : ${MARKO_FORCE}”
hr
}

# –– Detection –––––––––––––––––––––––––––––––

is_marko_installed() {
local target=”${WORKSPACE_DIR}/${MARKO_PROJECT_NAME}”

# Check both the target project dir and the workspace root (in case the

# project was scaffolded directly into the workspace).

for dir in “${target}” “${WORKSPACE_DIR}”; do
if [[ -d “${dir}/vendor/marko” ]]; then
echo “${dir}”
return 0
fi
if [[ -f “${dir}/composer.json” ]] && grep -q ‘“marko/’ “${dir}/composer.json” 2>/dev/null; then
echo “${dir}”
return 0
fi
done

return 1
}

# –– Install actions ––––––––––––––––––––––––––––

prepare_target() {
local target=”$1”
if [[ -e “${target}” && -n “$(ls -A “${target}” 2>/dev/null || true)” ]]; then
if [[ “${MARKO_FORCE}” == “1” ]]; then
warn “MARKO_FORCE=1 — removing existing non-empty target: ${target}”
rm -rf “${target}”
else
err “Target ‘${target}’ already exists and is not empty. Set MARKO_FORCE=1 to overwrite.”
exit 1
fi
fi
}

install_skeleton() {
local project_name=”$1”
local target=”${WORKSPACE_DIR}/${project_name}”
prepare_target “${target}”

info “composer create-project marko/skeleton ${project_name}”

# shellcheck disable=SC2086

( cd “${WORKSPACE_DIR}” && composer create-project marko/skeleton “${project_name}” ${MARKO_COMPOSER_FLAGS} )
echo “${target}”
}

install_framework() {
local project_name=”$1”
local target=”${WORKSPACE_DIR}/${project_name}”
prepare_target “${target}”
mkdir -p “${target}”

info “Bootstrapping bare composer project at ${target}”

# shellcheck disable=SC2086

( cd “${target}” && composer init   
–name=“app/${project_name}”   
–type=project   
–require=“php:^8.5”   
${MARKO_COMPOSER_FLAGS} >/dev/null )

info “composer require marko/framework”

# shellcheck disable=SC2086

( cd “${target}” && composer require marko/framework ${MARKO_COMPOSER_FLAGS} )
echo “${target}”
}

install_optional_packages() {
local project_dir=”$1”

# shellcheck disable=SC2206

local packages=( ${MARKO_PACKAGES} )

[[ ${#packages[@]} -eq 0 ]] && { info “No optional packages selected.”; return 0; }

local prod_pkgs=() dev_pkgs=()
for pkg in “${packages[@]}”; do
[[ -z “${pkg}” ]] && continue
if [[ “${pkg}” =~ ${MARKO_DEV_PACKAGES_REGEX} ]]; then
dev_pkgs+=(”${pkg}”)
else
prod_pkgs+=(”${pkg}”)
fi
done

if [[ ${#prod_pkgs[@]} -gt 0 ]]; then
info “composer require ${prod_pkgs[*]}”
# shellcheck disable=SC2086
( cd “${project_dir}” && composer require “${prod_pkgs[@]}” ${MARKO_COMPOSER_FLAGS} )
fi

if [[ ${#dev_pkgs[@]} -gt 0 ]]; then
info “composer require –dev ${dev_pkgs[*]}”
# shellcheck disable=SC2086
( cd “${project_dir}” && composer require –dev “${dev_pkgs[@]}” ${MARKO_COMPOSER_FLAGS} )
fi
}

# –– Main —————————————————————––

main() {
print_config
check_prereqs
validate_config

if existing_dir=”$(is_marko_installed)”; then
ok “Marko install detected at: ${existing_dir}”
info “Running composer install to sync dependencies.”
# shellcheck disable=SC2086
( cd “${existing_dir}” && composer install ${MARKO_COMPOSER_FLAGS} )
ok “Done.”
exit 0
fi

warn “No Marko installation found — scaffolding a new project.”

local project_dir
case “${MARKO_INSTALL_MODE}” in
skeleton)  project_dir=”$(install_skeleton  “${MARKO_PROJECT_NAME}”)” ;;
framework) project_dir=”$(install_framework “${MARKO_PROJECT_NAME}”)” ;;
esac

install_optional_packages “${project_dir}”

hr
ok “Marko project ready at: ${project_dir}”
echo
echo “Next steps:”
echo “  cd ${project_dir}”
[[ “${MARKO_INSTALL_MODE}” == “skeleton” ]] && echo “  php -S localhost:8000 -t public”
echo “  ./vendor/bin/marko    # list registered commands”
hr
}

main “$@”
