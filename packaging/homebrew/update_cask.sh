#!/usr/bin/env bash
# =============================================================================
# Tabami - Homebrew Cask Update Utility
# Usage: ./packaging/homebrew/update_cask.sh <version> <repo_owner>
# Example: ./packaging/homebrew/update_cask.sh 0.1.0 yourname
# =============================================================================

set -euo pipefail

VERSION="${1:-}"
REPO_OWNER="${2:-vitaliyl}"
CASK_FILE="$(dirname "$0")/Casks/tabami.rb"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [github_owner]"
  echo "Example: $0 0.1.0 myorg"
  exit 1
fi

# Strip leading 'v' if provided
VERSION="${VERSION#v}"

echo "==> Fetching SHA-256 checksums for Tabami v${VERSION} (${REPO_OWNER}/tabami)..."

ARM_URL="https://github.com/${REPO_OWNER}/tabami/releases/download/v${VERSION}/Tabami_${VERSION}_aarch64.dmg"
INTEL_URL="https://github.com/${REPO_OWNER}/tabami/releases/download/v${VERSION}/Tabami_${VERSION}_x64.dmg"

echo "==> Downloading and computing SHA-256 for Apple Silicon (aarch64)..."
ARM_SHA=$(curl -sL "$ARM_URL" | shasum -a 256 | awk '{print $1}')
echo "    aarch64 SHA-256: $ARM_SHA"

echo "==> Downloading and computing SHA-256 for Intel (x64)..."
INTEL_SHA=$(curl -sL "$INTEL_URL" | shasum -a 256 | awk '{print $1}')
echo "    x64 SHA-256:     $INTEL_SHA"

if [ -z "$ARM_SHA" ] || [ -z "$INTEL_SHA" ]; then
  echo "Error: Failed to compute checksums. Ensure release binaries exist at the URLs above."
  exit 1
fi

echo "==> Updating Cask file: $CASK_FILE..."

# Update version and sha256 in Cask file
sed -i.bak -E \
  -e "s/version \"[^\"]+\"/version \"${VERSION}\"/" \
  -e "s/sha256 arm:   \"[^\"]+\"/sha256 arm:   \"${ARM_SHA}\"/" \
  -e "s/intel: \"[^\"]+\"/intel: \"${INTEL_SHA}\"/" \
  -e "s|https://github.com/[^/]+/tabami|https://github.com/${REPO_OWNER}/tabami|g" \
  "$CASK_FILE"

rm -f "${CASK_FILE}.bak"

echo "==> Successfully updated $CASK_FILE for version ${VERSION}!"
