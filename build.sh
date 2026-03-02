#!/usr/bin/env bash
set -euo pipefail

#═══════════════════════════════════════════════════════════════════════════════
# build.sh — Build script for Web Navigator (Tauri App)
#
# Usage:
#   ./build.sh [--dev | --release]
#
#   --dev      Start Tauri dev server with hot-reload
#   --release  Build optimized release binary (default)
#═══════════════════════════════════════════════════════════════════════════════

APP_NAME="test"
APP_DISPLAY_NAME="Web Navigator"
APP_VERSION="0.1.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
info()  { echo -e "${BLUE}[i]${NC} $*"; }
header(){ echo -e "\n${BOLD}═══ $* ═══${NC}\n"; }

#───────────────────────────────────────────────────────────────────────────────
# Detect host target triple
#───────────────────────────────────────────────────────────────────────────────
detect_target() {
    local arch os
    arch="$(uname -m)"
    os="$(uname -s)"

    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) err "Unsupported architecture: $arch"; exit 1 ;;
    esac

    case "$os" in
        Linux)  echo "${arch}-unknown-linux-gnu" ;;
        Darwin) echo "${arch}-apple-darwin" ;;
        MINGW*|MSYS*|CYGWIN*) echo "${arch}-pc-windows-msvc" ;;
        *) err "Unsupported OS: $os"; exit 1 ;;
    esac
}

#───────────────────────────────────────────────────────────────────────────────
# Check a command exists
#───────────────────────────────────────────────────────────────────────────────
require_cmd() {
    local cmd="$1" install_hint="$2"
    if command -v "$cmd" &>/dev/null; then
        log "$cmd found: $(command -v "$cmd")"
    else
        err "$cmd not found"
        info "Install: $install_hint"
        return 1
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Check a pkg-config library exists
#───────────────────────────────────────────────────────────────────────────────
require_lib() {
    local lib="$1" install_hint="$2"
    if pkg-config --exists "$lib" 2>/dev/null; then
        log "$lib found ($(pkg-config --modversion "$lib" 2>/dev/null || echo 'version unknown'))"
    else
        err "$lib not found"
        info "Install: $install_hint"
        return 1
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# Check all dependencies
#───────────────────────────────────────────────────────────────────────────────
check_deps() {
    header "Checking Dependencies"
    local failed=0

    # Runtime tools
    require_cmd node  "https://nodejs.org/ or: nvm install --lts"          || ((failed++))
    require_cmd npm   "Comes with Node.js"                                  || ((failed++))
    require_cmd rustc "https://rustup.rs/"                                  || ((failed++))
    require_cmd cargo "https://rustup.rs/"                                  || ((failed++))
    require_cmd pkg-config "apt: pkg-config | dnf: pkgconf | pacman: pkgconf" || ((failed++))

    # System libraries (Linux only)
    if [[ "$(uname -s)" == "Linux" ]]; then
        local distro=""
        if command -v pacman &>/dev/null; then
            distro="arch"
        elif command -v apt &>/dev/null; then
            distro="debian"
        elif command -v dnf &>/dev/null; then
            distro="fedora"
        fi

        local gtk_hint webkit_hint gdk_hint
        case "$distro" in
            arch)
                gtk_hint="pacman -S gtk3"
                webkit_hint="pacman -S webkit2gtk-4.1"
                gdk_hint="pacman -S gtk3"
                ;;
            debian)
                gtk_hint="apt install libgtk-3-dev"
                webkit_hint="apt install libwebkit2gtk-4.1-dev"
                gdk_hint="apt install libgtk-3-dev"
                ;;
            fedora)
                gtk_hint="dnf install gtk3-devel"
                webkit_hint="dnf install webkit2gtk4.1-devel"
                gdk_hint="dnf install gtk3-devel"
                ;;
            *)
                gtk_hint="Install GTK 3 development package"
                webkit_hint="Install WebKit2GTK 4.1 development package"
                gdk_hint="Install GDK 3 development package"
                ;;
        esac

        require_lib "gtk+-3.0"       "$gtk_hint"    || ((failed++))
        require_lib "webkit2gtk-4.1" "$webkit_hint" || ((failed++))
        require_lib "gdk-3.0"        "$gdk_hint"    || ((failed++))
    fi

    if (( failed > 0 )); then
        echo ""
        err "$failed missing dependency(ies). Install them and re-run."
        exit 1
    fi
    log "All dependencies satisfied."
}

#───────────────────────────────────────────────────────────────────────────────
# Install frontend dependencies
#───────────────────────────────────────────────────────────────────────────────
install_frontend() {
    header "Installing Frontend Dependencies"
    npm install
    log "Frontend dependencies installed."
}

#───────────────────────────────────────────────────────────────────────────────
# Dev mode
#───────────────────────────────────────────────────────────────────────────────
run_dev() {
    header "Starting Dev Server"
    info "Hot-reload is active. Press Ctrl+C to stop."
    npx tauri dev
}

#───────────────────────────────────────────────────────────────────────────────
# Release build
#───────────────────────────────────────────────────────────────────────────────
build_release() {
    local target="$1"
    header "Building Release ($target)"
    npx tauri build --target "$target"
    log "Tauri build complete."
}

#───────────────────────────────────────────────────────────────────────────────
# Create .run self-extracting installer (Linux)
#───────────────────────────────────────────────────────────────────────────────
create_run_installer() {
    local target="$1"
    header "Creating .run Installer"

    local binary_name="$APP_NAME"
    local bundle_dir="src-tauri/target/${target}/release"
    local staging_dir="$(mktemp -d)"
    local run_file="${APP_NAME}-${APP_VERSION}-${target}.run"

    trap "rm -rf '$staging_dir'" EXIT

    if [[ ! -f "${bundle_dir}/${binary_name}" ]]; then
        err "Release binary not found at ${bundle_dir}/${binary_name}"
        exit 1
    fi

    # Copy and strip binary
    cp "${bundle_dir}/${binary_name}" "${staging_dir}/"
    strip "${staging_dir}/${binary_name}" 2>/dev/null || true

    # Copy icons
    if [[ -d "src-tauri/icons" ]]; then
        mkdir -p "${staging_dir}/icons"
        cp -r src-tauri/icons/* "${staging_dir}/icons/" 2>/dev/null || true
    fi

    # Create .desktop entry
    cat > "${staging_dir}/${APP_NAME}.desktop" <<DESKTOP
[Desktop Entry]
Name=${APP_DISPLAY_NAME}
Comment=Cross-platform web navigator
Exec=/opt/${APP_NAME}/${binary_name}
Icon=/opt/${APP_NAME}/icons/128x128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupWMClass=${APP_NAME}
DESKTOP

    # Create install.sh
    cat > "${staging_dir}/install.sh" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
APP_NAME="test"
DISPLAY_NAME="Web Navigator"
INSTALL_DIR="/opt/${APP_NAME}"

if [[ $EUID -ne 0 ]]; then
    echo "This installer requires root privileges."
    echo "Run: sudo ./install.sh"
    exit 1
fi

echo "Installing ${DISPLAY_NAME}..."
mkdir -p "${INSTALL_DIR}"
cp -r ./* "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}/${APP_NAME}"

# Desktop entry
if [[ -d /usr/share/applications ]]; then
    cp "${INSTALL_DIR}/${APP_NAME}.desktop" /usr/share/applications/
fi

# Symlink
ln -sf "${INSTALL_DIR}/${APP_NAME}" /usr/local/bin/${APP_NAME}

echo ""
echo "✓ ${DISPLAY_NAME} installed to ${INSTALL_DIR}"
echo "  Run with: ${APP_NAME}"
echo ""
echo "To uninstall:"
echo "  sudo rm -rf ${INSTALL_DIR}"
echo "  sudo rm -f /usr/local/bin/${APP_NAME}"
echo "  sudo rm -f /usr/share/applications/${APP_NAME}.desktop"
INSTALL
    chmod +x "${staging_dir}/install.sh"

    # Build .run
    if command -v makeself &>/dev/null; then
        log "Using makeself for .run package"
        makeself --nox11 "${staging_dir}" "${run_file}" "${APP_DISPLAY_NAME} Installer" ./install.sh
    else
        warn "makeself not found — using tar-based self-extractor"
        {
            cat <<'HEADER'
#!/usr/bin/env bash
set -euo pipefail
echo "Self-extracting installer..."
ARCHIVE_START=$(awk '/^__ARCHIVE_BELOW__$/{print NR + 1; exit 0;}' "$0")
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT
tail -n "+$ARCHIVE_START" "$0" | tar xz -C "$TMPDIR"
cd "$TMPDIR"
exec ./install.sh
__ARCHIVE_BELOW__
HEADER
            tar cz -C "${staging_dir}" .
        } > "${run_file}"
        chmod +x "${run_file}"
    fi

    log "Created: ${run_file}"
    trap - EXIT
    rm -rf "$staging_dir"
}

#───────────────────────────────────────────────────────────────────────────────
# Summary
#───────────────────────────────────────────────────────────────────────────────
print_summary() {
    local target="$1"
    local bundle_dir="src-tauri/target/${target}/release/bundle"

    header "Build Summary"
    echo -e "  App:      ${BOLD}${APP_DISPLAY_NAME}${NC} v${APP_VERSION}"
    echo -e "  Target:   ${target}"
    echo ""

    if [[ -d "$bundle_dir" ]]; then
        echo -e "  ${BOLD}Packages:${NC}"
        find "$bundle_dir" -type f \( -name "*.deb" -o -name "*.rpm" -o -name "*.AppImage" \
            -o -name "*.dmg" -o -name "*.app" -o -name "*.exe" -o -name "*.msi" \) \
            -exec echo "    {}" \; 2>/dev/null || true
    fi

    if ls ./*.run &>/dev/null; then
        echo -e "    $(ls ./*.run)"
    fi

    echo ""
    echo -e "  ${BOLD}Install (.run):${NC}"
    echo "    chmod +x ${APP_NAME}-*.run"
    echo "    sudo ./${APP_NAME}-*.run"
    echo ""
    echo -e "  ${BOLD}Uninstall:${NC}"
    echo "    sudo rm -rf /opt/${APP_NAME}"
    echo "    sudo rm -f /usr/local/bin/${APP_NAME}"
    echo "    sudo rm -f /usr/share/applications/${APP_NAME}.desktop"
}

#───────────────────────────────────────────────────────────────────────────────
# Main
#───────────────────────────────────────────────────────────────────────────────
main() {
    local mode="release"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dev)     mode="dev";     shift ;;
            --release) mode="release"; shift ;;
            -h|--help)
                echo "Usage: $0 [--dev | --release]"
                echo "  --dev      Start Tauri dev server"
                echo "  --release  Build optimized release (default)"
                exit 0
                ;;
            *) err "Unknown option: $1"; exit 1 ;;
        esac
    done

    local target
    target="$(detect_target)"

    header "${APP_DISPLAY_NAME} — Build (${mode})"
    info "Target: ${target}"

    check_deps
    install_frontend

    if [[ "$mode" == "dev" ]]; then
        run_dev
    else
        build_release "$target"

        # Create .run on Linux
        if [[ "$(uname -s)" == "Linux" ]]; then
            create_run_installer "$target"
        fi

        print_summary "$target"
    fi
}

main "$@"
