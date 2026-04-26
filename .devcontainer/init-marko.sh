#!/usr/bin/env bash

# init-marko.sh
# Devcontainer post-create init script for Marko.build projects.
#
# Behavior:
# 1) If Marko is already installed, run composer install and exit.
# 2) Otherwise scaffold a new project, then require optional packages.
#
# Safe to run repeatedly. Designed for devcontainer.json postCreateCommand.

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Workspace directory (parent of the project folder).
WORKSPACE_DIR="${WORKSPACE_DIR:-${PWD}}"

# Project name for the created folder.
MARKO_PROJECT_NAME="${MARKO_PROJECT_NAME:-my-app}"

# Install mode: skeleton | framework
MARKO_INSTALL_MODE="${MARKO_INSTALL_MODE:-skeleton}"

# Space-separated optional composer packages.
MARKO_PACKAGES="${MARKO_PACKAGES:-marko/database marko/session marko/view marko/security marko/testing marko/dev-server}"

# Packages matching this regex are installed with --dev.
MARKO_DEV_PACKAGES_REGEX="${MARKO_DEV_PACKAGES_REGEX:-^(marko/testing|marko/dev-server)$}"

# If 1, overwrite a non-empty target directory.
MARKO_FORCE="${MARKO_FORCE:-0}"

# If 1, skip the PHP >= 8.5 check.
MARKO_SKIP_PHP_CHECK="${MARKO_SKIP_PHP_CHECK:-0}"

# Extra flags passed to all composer commands.
MARKO_COMPOSER_FLAGS="${MARKO_COMPOSER_FLAGS:---no-interaction}"

# =============================================================================
# END CONFIGURATION
# =============================================================================

C_RESET="\033[0m"; C_BOLD="\033[1m"; C_DIM="\033[2m"
C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BLUE="\033[34m"; C_RED="\033[31m"

info()  { printf "%b==>%b %s\n" "${C_BLUE}" "${C_RESET}" "$*"; }
ok()    { printf "%b[OK]%b %s\n" "${C_GREEN}" "${C_RESET}" "$*"; }
warn()  { printf "%b[!]%b %s\n" "${C_YELLOW}" "${C_RESET}" "$*"; }
err()   { printf "%b[X]%b %s\n" "${C_RED}" "${C_RESET}" "$*" >&2; }
hr()    { printf "%b--------------------------------%b\n" "${C_DIM}" "${C_RESET}"; }

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		err "Required command '$1' not found in PATH."
		exit 1
	}
}

check_prereqs() {
	info "Checking prerequisites"
	require_cmd php
	require_cmd composer

	local php_ver
	php_ver="$(php -r 'echo PHP_VERSION;')"
	ok "PHP ${php_ver}"
	ok "Composer $(composer --version --no-ansi 2>/dev/null | awk '{print $3}')"

	if [[ "${MARKO_SKIP_PHP_CHECK}" != "1" ]]; then
		if ! php -r 'exit(version_compare(PHP_VERSION, "8.5.0", ">=") ? 0 : 1);'; then
			warn "Marko requires PHP 8.5+. Current PHP is ${php_ver}. Install may fail."
			warn "Set MARKO_SKIP_PHP_CHECK=1 to silence this warning."
		fi
	fi
}

validate_config() {
	if [[ ! "${MARKO_PROJECT_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		err "Invalid MARKO_PROJECT_NAME '${MARKO_PROJECT_NAME}'. Allowed: a-z A-Z 0-9 _ -"
		exit 1
	fi

	case "${MARKO_INSTALL_MODE}" in
		skeleton|framework) ;;
		*)
			err "Invalid MARKO_INSTALL_MODE '${MARKO_INSTALL_MODE}'. Expected: skeleton | framework"
			exit 1
			;;
	esac

	if [[ ! -d "${WORKSPACE_DIR}" ]]; then
		err "WORKSPACE_DIR '${WORKSPACE_DIR}' does not exist."
		exit 1
	fi
}

print_config() {
	hr
	printf "%bMarko.build devcontainer init%b\n" "${C_BOLD}" "${C_RESET}"
	hr
	echo "  Workspace    : ${WORKSPACE_DIR}"
	echo "  Project name : ${MARKO_PROJECT_NAME}"
	echo "  Install mode : marko/${MARKO_INSTALL_MODE}"
	if [[ -n "${MARKO_PACKAGES// }" ]]; then
		echo "  Extra pkgs   : ${MARKO_PACKAGES}"
	else
		echo "  Extra pkgs   : (none)"
	fi
	echo "  Force        : ${MARKO_FORCE}"
	hr
}

is_marko_installed() {
	local target="${WORKSPACE_DIR}/${MARKO_PROJECT_NAME}"

	# Check target dir and workspace root in case project was scaffolded at root.
	for dir in "${target}" "${WORKSPACE_DIR}"; do
		if [[ -d "${dir}/vendor/marko" ]]; then
			echo "${dir}"
			return 0
		fi
		if [[ -f "${dir}/composer.json" ]] && grep -q '"marko/' "${dir}/composer.json" 2>/dev/null; then
			echo "${dir}"
			return 0
		fi
	done

	return 1
}

prepare_target() {
	local target="$1"
	if [[ -e "${target}" && -n "$(ls -A "${target}" 2>/dev/null || true)" ]]; then
		if [[ "${MARKO_FORCE}" == "1" ]]; then
			warn "MARKO_FORCE=1: removing existing non-empty target: ${target}"
			rm -rf "${target}"
		else
			err "Target '${target}' already exists and is not empty. Set MARKO_FORCE=1 to overwrite."
			exit 1
		fi
	fi
}

install_skeleton() {
	local project_name="$1"
	local target="${WORKSPACE_DIR}/${project_name}"
	prepare_target "${target}"

	info "composer create-project marko/skeleton ${project_name}" >&2

	# shellcheck disable=SC2086
	( cd "${WORKSPACE_DIR}" && composer create-project marko/skeleton "${project_name}" ${MARKO_COMPOSER_FLAGS} ) >&2
	echo "${target}"
}

install_framework() {
	local project_name="$1"
	local target="${WORKSPACE_DIR}/${project_name}"
	prepare_target "${target}"
	mkdir -p "${target}"

	info "Bootstrapping bare composer project at ${target}" >&2

	# shellcheck disable=SC2086
	(
		cd "${target}" &&
			composer init \
				--name="app/${project_name}" \
				--type=project \
				--require="php:^8.5" \
				${MARKO_COMPOSER_FLAGS} >/dev/null
	) >&2

	info "composer require marko/framework" >&2

	# shellcheck disable=SC2086
	( cd "${target}" && composer require marko/framework ${MARKO_COMPOSER_FLAGS} ) >&2
	echo "${target}"
}

install_optional_packages() {
	local project_dir="$1"

	# shellcheck disable=SC2206
	local packages=( ${MARKO_PACKAGES} )

	[[ ${#packages[@]} -eq 0 ]] && {
		info "No optional packages selected."
		return 0
	}

	local prod_pkgs=() dev_pkgs=()
	for pkg in "${packages[@]}"; do
		[[ -z "${pkg}" ]] && continue
		if [[ "${pkg}" =~ ${MARKO_DEV_PACKAGES_REGEX} ]]; then
			dev_pkgs+=("${pkg}")
		else
			prod_pkgs+=("${pkg}")
		fi
	done

	if [[ ${#prod_pkgs[@]} -gt 0 ]]; then
		info "composer require ${prod_pkgs[*]}"
		# shellcheck disable=SC2086
		( cd "${project_dir}" && composer require "${prod_pkgs[@]}" ${MARKO_COMPOSER_FLAGS} )
	fi

	if [[ ${#dev_pkgs[@]} -gt 0 ]]; then
		info "composer require --dev ${dev_pkgs[*]}"
		# shellcheck disable=SC2086
		( cd "${project_dir}" && composer require --dev "${dev_pkgs[@]}" ${MARKO_COMPOSER_FLAGS} )
	fi
}

register_path() {
	local vendor_bin="$1/vendor/bin"
	local marker="# marko vendor/bin"
	if ! grep -qF "${marker}" ~/.bashrc 2>/dev/null; then
		printf '\n%s\nexport PATH="%s:$PATH"\n' "${marker}" "${vendor_bin}" >> ~/.bashrc
	else
		# Update in case project dir changed
		sed -i "s|export PATH=\".*/vendor/bin:\\\$PATH\"|export PATH=\"${vendor_bin}:\$PATH\"|" ~/.bashrc
	fi
}

main() {
	print_config
	check_prereqs
	validate_config

	local existing_dir
	if existing_dir="$(is_marko_installed)"; then
		ok "Marko install detected at: ${existing_dir}"
		info "Running composer install to sync dependencies."
		# shellcheck disable=SC2086
		( cd "${existing_dir}" && composer install ${MARKO_COMPOSER_FLAGS} )
		register_path "${existing_dir}"
		ok "Done."
		exit 0
	fi

	warn "No Marko installation found; scaffolding a new project."

	local project_dir
	case "${MARKO_INSTALL_MODE}" in
		skeleton)  project_dir="$(install_skeleton "${MARKO_PROJECT_NAME}")" ;;
		framework) project_dir="$(install_framework "${MARKO_PROJECT_NAME}")" ;;
	esac

	install_optional_packages "${project_dir}"
	register_path "${project_dir}"

	hr
	ok "Marko project ready at: ${project_dir}"
	echo
	echo "Next steps:"
	echo "  cd ${project_dir}"
	[[ "${MARKO_INSTALL_MODE}" == "skeleton" ]] && echo "  php -S localhost:8000 -t public"
	echo "  marko    # list registered commands"
	hr
}

main "$@"
