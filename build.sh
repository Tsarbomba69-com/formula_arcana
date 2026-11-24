#!/usr/bin/env bash
set -euo pipefail

# Configuration
SRC_DIR="src"
BIN_DIR="bin"
RELEASE_DIR="${BIN_DIR}/release"
DEBUG_DIR="${BIN_DIR}/debug"
ASSETS_SRC="assets"
GAME_NAME="game"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) MODULE_EXT="dll" ;;
    Darwin*) MODULE_EXT="dylib" ;;
    *) MODULE_EXT="so" ;;
esac
MODULE_CANDIDATE="${DEBUG_DIR}/game_module_candidate.${MODULE_EXT}"
VET_FLAGS="-warnings-as-errors -vet-unused -vet-shadowing -vet-using-param -vet-using-stmt -vet-style"

mkdir -p "${BIN_DIR}"
mkdir -p "${BIN_DIR}/debug"
mkdir -p "${BIN_DIR}/release"

usage() {
    echo "Usage: ./build.sh <command> [mode]"
    echo ""
    echo "Commands:"
    echo "  format           Format all source files using odinfmt"
    echo "  build [mode]     Compile binary (mode: debug [default], release)"
    echo "  module           Build the reloadable debug game module"
    echo "  run [mode]       Compile and execute binary (mode: debug [default], release)"
    echo "  test             Run test suite across all packages"
    echo "  clean            Remove built binaries and build artifacts"
    exit 1
}

cmd_format() {
    echo "[odinfmt] Formatting source code..."
    if command -v odinfmt >/dev/null 2>&1; then
        odinfmt -w "${SRC_DIR}"
        echo "[odinfmt] Done."
    else
        echo "Error: 'odinfmt' binary not found in PATH." >&2
        exit 1
    fi
}

copy_assets() {
    local target_dir="$1"
    if [ -d "${ASSETS_SRC}" ]; then
        echo "[assets] Copying assets to ${target_dir}/assets..."
        mkdir -p "${target_dir}/assets"
        cp -R "${ASSETS_SRC}/." "${target_dir}/assets/"
    else
        echo "[assets] Warning: 'assets/' directory not found at project root."
    fi
}

cmd_build() {
    local mode="${1:-debug}"
    local target_dir="${BIN_DIR}/${mode}"
    case "${mode}" in
        debug)
            echo "[odin] Building DEBUG target..."
            odin build "${SRC_DIR}" -out:"${DEBUG_DIR}/${GAME_NAME}" -debug -o:none ${VET_FLAGS}
            cmd_module
            ;;
        release)
            echo "[odin] Building RELEASE target..."
            odin build "${SRC_DIR}" -out:"${RELEASE_DIR}/${GAME_NAME}" -o:speed ${VET_FLAGS}
            cmd_module
            ;;
        *)
            echo "Error: Unknown build mode '${mode}'. Use 'debug' or 'release'." >&2
            exit 1
            ;;
    esac
    copy_assets "${target_dir}"
    echo "[odin] Build successful -> ${target_dir}/${GAME_NAME}"
    echo "[odin] Build successful -> ${BIN_DIR}/${mode}/${GAME_NAME}"
}

cmd_module() {
    echo "[odin] Building reloadable game module..."
    odin build "${SRC_DIR}/game_module" -build-mode:dll -out:"${MODULE_CANDIDATE}" -debug -o:none ${VET_FLAGS}
    echo "[odin] Module candidate -> ${MODULE_CANDIDATE}"
}

cmd_run() {
    local mode="${1:-debug}"
    case "${mode}" in
        debug)
            echo "[odin] Running DEBUG build..."
            cmd_build debug
            "${DEBUG_DIR}/${GAME_NAME}"
            ;;
        release)
            echo "[odin] Running RELEASE build..."
            cmd_build release
            "${RELEASE_DIR}/${GAME_NAME}"
            ;;
        *)
            echo "Error: Unknown run mode '${mode}'. Use 'debug' or 'release'." >&2
            exit 1
            ;;
    esac
}

cmd_test() {
    echo "[odin] Running core tests..."
    odin test "${SRC_DIR}/core" ${VET_FLAGS}

    echo "[odin] Running feature tests..."
    odin test "${SRC_DIR}/features" ${VET_FLAGS}

    echo "[odin] Running algebra tests..."
    odin test "${SRC_DIR}/algebra" ${VET_FLAGS}
}

cmd_clean() {
    echo "[clean] Removing build artifacts..."
    rm -rf "${BIN_DIR}"/*
    echo "[clean] Clean complete."
}

# Command dispatch
case "${1:-}" in
    format) cmd_format ;;
    build)  cmd_build "${2:-debug}" ;;
    module) cmd_module ;;
    run)    cmd_run "${2:-debug}" ;;
    test)   cmd_test ;;
    clean)  cmd_clean ;;
    *)      usage ;;
esac
