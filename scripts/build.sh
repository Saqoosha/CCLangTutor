#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"

CONFIGURATION="${1:-Debug}"

mkdir -p "${BUILD_DIR}"

# Regenerate Xcode project from project.yml
xcodegen generate --spec "${ROOT_DIR}/project.yml"

# Build app
xcodebuild \
  -scheme CCLangTutor \
  -configuration "${CONFIGURATION}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  build

# Build CLI
xcodebuild \
  -scheme notifier \
  -configuration "${CONFIGURATION}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  build

# Copy CLI into app bundle
APP_PATH="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/CCLangTutor.app"
CLI_PATH="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/notifier"

if [[ -f "$CLI_PATH" && -d "$APP_PATH" ]]; then
  cp "$CLI_PATH" "${APP_PATH}/Contents/MacOS/"
  echo "Copied notifier CLI into app bundle"
fi

echo "Built app:"
echo "${APP_PATH}"
