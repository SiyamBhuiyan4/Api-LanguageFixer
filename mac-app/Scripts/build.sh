#!/usr/bin/env bash
# ==============================================================================
# BanglaWrite AI — Native macOS Build & Packaging Script
# Target: macOS 12.0+ Monterey (Intel x86_64)
# Toolchain: swiftc (Cocoa, Carbon)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="BanglaWriteAI"
BUNDLE_ID="com.banglawrite.ai.mac"
TARGET_ARCH="x86_64-apple-macos12.0"

SRC_DIR="${PROJECT_ROOT}/Sources"
RES_DIR="${PROJECT_ROOT}/Resources"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
CLI_BIN="${BUILD_DIR}/${APP_NAME}"

BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; }

clean() {
    log_info "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    log_success "Clean completed."
}

check_prerequisites() {
    log_info "Checking toolchain prerequisites..."
    for tool in swiftc plutil codesign; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            log_error "Required tool '${tool}' is not available in PATH."
            exit 1
        fi
    done
    local swift_version
    swift_version="$(swiftc --version | head -n 1)"
    log_info "Compiler: ${swift_version}"
}

generate_icon() {
    local target_icns="${RES_DIR}/AppIcon.icns"
    if [[ -f "${target_icns}" ]]; then
        return 0
    fi

    local source_png=""
    for cand in "${PROJECT_ROOT}/../icons/icon-128.png" "${PROJECT_ROOT}/../icons/icon128.png"; do
        if [[ -f "${cand}" ]]; then
            source_png="${cand}"
            break
        fi
    done

    if [[ -n "${source_png}" ]] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
        local iconset_dir="${BUILD_DIR}/AppIcon.iconset"
        mkdir -p "${iconset_dir}"
        sips -z 16 16     "${source_png}" --out "${iconset_dir}/icon_16x16.png" >/dev/null 2>&1 || true
        sips -z 32 32     "${source_png}" --out "${iconset_dir}/icon_16x16@2x.png" >/dev/null 2>&1 || true
        sips -z 32 32     "${source_png}" --out "${iconset_dir}/icon_32x32.png" >/dev/null 2>&1 || true
        sips -z 64 64     "${source_png}" --out "${iconset_dir}/icon_32x32@2x.png" >/dev/null 2>&1 || true
        sips -z 128 128   "${source_png}" --out "${iconset_dir}/icon_128x128.png" >/dev/null 2>&1 || true
        sips -z 256 256   "${source_png}" --out "${iconset_dir}/icon_128x128@2x.png" >/dev/null 2>&1 || true
        iconutil -c icns "${iconset_dir}" -o "${target_icns}" >/dev/null 2>&1 || true
        rm -rf "${iconset_dir}"
    fi
}

compile_app() {
    log_info "Compiling Swift sources from ${SRC_DIR}..."
    local swift_files=()
    while IFS= read -r file; do
        [[ -n "${file}" ]] && swift_files+=("${file}")
    done < <(find "${SRC_DIR}" -name "*.swift" | sort)

    mkdir -p "${MACOS_DIR}" "${BUILD_DIR}"
    local target_bin="${MACOS_DIR}/${APP_NAME}"

    swiftc \
        -O \
        -whole-module-optimization \
        -target "${TARGET_ARCH}" \
        -framework Cocoa \
        -framework Carbon \
        -framework SwiftUI \
        "${swift_files[@]}" \
        -o "${target_bin}"

    log_success "Compiled native Mach-O binary: ${target_bin}"

    # Also copy to standalone CLI binary
    cp -f "${target_bin}" "${CLI_BIN}"
    chmod +x "${CLI_BIN}"
    log_success "Standalone CLI binary ready: ${CLI_BIN}"
}

assemble_bundle() {
    log_info "Packaging macOS application bundle (${APP_BUNDLE})..."
    mkdir -p "${CONTENTS_DIR}" "${MACOS_DIR}" "${RESOURCES_DIR}"

    echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

    if [[ -f "${RES_DIR}/Info.plist" ]]; then
        cp -f "${RES_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"
        plutil -lint "${CONTENTS_DIR}/Info.plist" >/dev/null
    fi

    if [[ -f "${RES_DIR}/AppIcon.icns" ]]; then
        cp -f "${RES_DIR}/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
    fi

    log_info "Applying local ad-hoc code signature..."
    codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true
    log_success "Created: ${APP_BUNDLE}"
}

verify_bundle() {
    log_info "Verifying build outputs..."
    if [[ -f "${MACOS_DIR}/${APP_NAME}" ]] && [[ -f "${CONTENTS_DIR}/Info.plist" ]]; then
        log_success "Build verification PASSED!"
        echo ""
        echo -e "${BOLD}To launch BanglaWrite AI:${RESET}"
        echo -e "  Application Bundle : ${GREEN}open \"${APP_BUNDLE}\"${RESET}"
        echo -e "  CLI Daemon Mode    : ${GREEN}\"${CLI_BIN}\"${RESET}"
        echo ""
    else
        log_error "Build verification FAILED."
        exit 1
    fi
}

main() {
    local action="${1:-all}"
    case "${action}" in
        clean) clean ;;
        compile) check_prerequisites; compile_app ;;
        verify|test)
            "${PROJECT_ROOT}/test/verify_native.sh"
            ;;
        bundle|all)
            check_prerequisites
            mkdir -p "${BUILD_DIR}"
            generate_icon
            compile_app
            assemble_bundle
            verify_bundle
            ;;
        *)
            echo "Usage: $0 {all|compile|bundle|clean}"
            exit 1
            ;;
    esac
}

main "$@"
