#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${APP_DIR}/build"
mkdir -p "${BUILD_DIR}"

TEST_BIN="${BUILD_DIR}/test_runner"

echo "Building BanglaWrite AI Native Verification Suite..."
swiftc \
    -target x86_64-apple-macos12.0 \
    -O \
    -framework Cocoa \
    -framework Carbon \
    "${APP_DIR}/Sources/Models.swift" \
    "${APP_DIR}/Sources/PromptEngine.swift" \
    "${APP_DIR}/Sources/OfflineBanglaEngine.swift" \
    "${APP_DIR}/Sources/APIClient.swift" \
    "${SCRIPT_DIR}/test_native.swift" \
    -o "${TEST_BIN}"

echo "Executing Native Verification Suite..."
"${TEST_BIN}"
