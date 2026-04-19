#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Marko Framework — Codespace Setup Script
# Checks if Marko is installed, and if not, walks through
# project creation with interactive options.
# ─────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║        Marko Framework Setup             ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Pre-flight checks ────────────────────────────────────────

check_prerequisites() {
    local missing=0

    if ! command -v php &>/dev/null; then
        error "PHP is not installed."
        missing=1
    else
        success "PHP $(php -r 'echo PHP_VERSION;') found"
    fi

    if ! command -v composer &>/dev/null; then
        error "Composer is not installed."
        missing=1
    else
        success "Composer $(composer --version 2>/dev/null | grep -oP '[\d.]+' | head -1) found"
    fi

    if [[ $missing -eq 1 ]]; then
        error "Please install the missing prerequisites and re-run this script."
        exit 1
    fi
}

# ── Detect existing Marko installation ────────────────────────

check_marko_installed() {
    # Check if we're inside a Marko project (composer.json requires marko/framework)
    if [[ -f "composer.json" ]] && grep -q '"marko/framework"' composer.json 2>/dev/null; then
        return 0
    fi

    # Check if the marko CLI is available
    if command -v marko &>/dev/null; then
        return 0
    fi

    # Check vendor directory for marko packages
    if [[ -d "vendor/marko" ]]; then
        return 0
    fi

    return 1
}

# ── Prompt helpers ────────────────────────────────────────────

prompt_project_name() {
    local default="my-app"
    echo ""
    read -rp "$(echo -e "${BOLD}Project name${NC} [${default}]: ")" PROJECT_NAME
    PROJECT_NAME="${PROJECT_NAME:-$default}"

    # Sanitize: lowercase, replace spaces/underscores with hyphens
    PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g')

    if [[ -d "$PROJECT_NAME" ]]; then
        warn "Directory '$PROJECT_NAME' already exists."
        read -rp "Overwrite? (y/N): " overwrite
        if [[ "${overwrite,,}" != "y" ]]; then
            error "Aborting. Choose a different project name."
            exit 1
        fi
        rm -rf "$PROJECT_NAME"
    fi

    success "Project name: $PROJECT_NAME"
}

prompt_project_type() {
    echo ""
    echo -e "${BOLD}Choose a project type:${NC}"
    echo ""
    echo "  1) Skeleton    — Minimal setup with routing, a single module,"
    echo "                    and dev server. Best for starting from scratch."
    echo ""
    echo "  2) Full App    — Complete web application with authentication,"
    echo "                    database migrations, queue workers, mail,"
    echo "                    and example modules pre-configured."
    echo ""
    read -rp "$(echo -e "${BOLD}Selection${NC} [1]: ")" type_choice
    type_choice="${type_choice:-1}"

    case "$type_choice" in
        1) PROJECT_TYPE="marko/skeleton"
           success "Project type: Skeleton" ;;
        2) PROJECT_TYPE="marko/webapp"
           success "Project type: Full Web Application" ;;
        *) warn "Invalid choice, defaulting to Skeleton."
           PROJECT_TYPE="marko/skeleton"
           success "Project type: Skeleton" ;;
    esac
}

prompt_additional_packages() {
    echo ""
    echo -e "${BOLD}Additional Marko packages (select all that apply):${NC}"
    echo ""
    echo "  1) marko/auth          — Authentication & authorization"
    echo "  2) marko/database      — Database ORM & migrations"
    echo "  3) marko/queue         — Background job processing"
    echo "  4) marko/mail          — Email sending"
    echo "  5) marko/cache         — Cache drivers (file, Redis, etc.)"
    echo "  6) marko/events        — Event dispatcher & listeners"
    echo "  7) marko/validation    — Request validation"
    echo "  8) marko/testing       — Testing utilities"
    echo ""
    echo "  Enter numbers separated by spaces, or press Enter to skip."
    echo ""
    read -rp "$(echo -e "${BOLD}Packages${NC}: ")" package_choices

    ADDITIONAL_PACKAGES=()

    if [[ -n "$package_choices" ]]; then
        for choice in $package_choices; do
            case "$choice" in
                1) ADDITIONAL_PACKAGES+=("marko/auth") ;;
                2) ADDITIONAL_PACKAGES+=("marko/database") ;;
                3) ADDITIONAL_PACKAGES+=("marko/queue") ;;
                4) ADDITIONAL_PACKAGES+=("marko/mail") ;;
                5) ADDITIONAL_PACKAGES+=("marko/cache") ;;
                6) ADDITIONAL_PACKAGES+=("marko/events") ;;
                7) ADDITIONAL_PACKAGES+=("marko/validation") ;;
                8) ADDITIONAL_PACKAGES+=("marko/testing") ;;
                *) warn "Skipping unknown option: $choice" ;;
            esac
        done
    fi

    if [[ ${#ADDITIONAL_PACKAGES[@]} -gt 0 ]]; then
        success "Additional packages: ${ADDITIONAL_PACKAGES[*]}"
    else
        info "No additional packages selected."
    fi
}

# ── Installation ──────────────────────────────────────────────

install_marko() {
    echo ""
    echo -e "${BOLD}━━━ Creating project ━━━${NC}"
    echo ""
    info "Running: composer create-project $PROJECT_TYPE $PROJECT_NAME"
    echo ""

    composer create-project "$PROJECT_TYPE" "$PROJECT_NAME" --no-interaction

    echo ""
    success "Project created at ./$PROJECT_NAME"

    # Install additional packages
    if [[ ${#ADDITIONAL_PACKAGES[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}━━━ Installing additional packages ━━━${NC}"
        echo ""

        cd "$PROJECT_NAME"
        for pkg in "${ADDITIONAL_PACKAGES[@]}"; do
            info "Installing $pkg ..."
            composer require "$pkg" --no-interaction
        done
        cd ..

        echo ""
        success "All additional packages installed."
    fi
}

# ── Post-install setup ────────────────────────────────────────

post_install() {
    echo ""
    echo -e "${BOLD}━━━ Post-install setup ━━━${NC}"
    echo ""

    cd "$PROJECT_NAME"

    # Copy .env.example to .env if it exists
    if [[ -f ".env.example" && ! -f ".env" ]]; then
        cp .env.example .env
        success "Created .env from .env.example"
    fi

    cd ..

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Setup complete!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo "    cd $PROJECT_NAME"
    echo "    composer install"
    echo "    marko up"
    echo ""
    echo -e "  Then visit ${CYAN}http://localhost:8000${NC}"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────

main() {
    print_banner
    check_prerequisites

    echo ""

    # Check if Marko is already set up in the current directory
    if check_marko_installed; then
        success "Marko is already installed in this project."
        echo ""

        # Show installed marko packages
        if [[ -f "composer.json" ]]; then
            info "Installed Marko packages:"
            grep -oP '"marko/[^"]+"' composer.json 2>/dev/null | tr -d '"' | while read -r pkg; do
                echo "    - $pkg"
            done
        fi

        echo ""
        read -rp "$(echo -e "Would you like to create a ${BOLD}new${NC} Marko project in a subdirectory? (y/N): ")" create_new
        if [[ "${create_new,,}" != "y" ]]; then
            info "Nothing to do. Exiting."
            exit 0
        fi
    else
        info "Marko is not installed. Let's set it up!"
    fi

    prompt_project_name
    prompt_project_type
    prompt_additional_packages

    # Confirm before proceeding
    echo ""
    echo -e "${BOLD}━━━ Summary ━━━${NC}"
    echo ""
    echo "  Project name:  $PROJECT_NAME"
    echo "  Project type:  $PROJECT_TYPE"
    if [[ ${#ADDITIONAL_PACKAGES[@]} -gt 0 ]]; then
        echo "  Extra packages: ${ADDITIONAL_PACKAGES[*]}"
    else
        echo "  Extra packages: (none)"
    fi
    echo ""
    read -rp "$(echo -e "${BOLD}Proceed with installation?${NC} (Y/n): ")" confirm
    if [[ "${confirm,,}" == "n" ]]; then
        info "Installation cancelled."
        exit 0
    fi

    install_marko
    post_install
}

main "$@"
