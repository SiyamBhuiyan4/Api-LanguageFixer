#!/usr/bin/env bash
# Launch helper for BanglaWrite AI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_BUNDLE="${PROJECT_ROOT}/build/BanglaWriteAI.app"

if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "App bundle not found. Building first..."
    "${SCRIPT_DIR}/build.sh" all
fi

echo "Launching BanglaWrite AI..."
open "${APP_BUNDLE}"
