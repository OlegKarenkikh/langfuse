#!/usr/bin/env sh
set -eu

KYS_PATH="packages/kysely"
KYS_REPO="https://github.com/Olegkarenkikh/kysely.git"
KYS_COMMIT="64a12c470b1a5387b842acf09094e2aa1e4149b0"

if [ -f "$KYS_PATH/package.json" ]; then
  echo "Kysely already present in $KYS_PATH"
  exit 0
fi

echo "Fetching Kysely from $KYS_REPO at commit $KYS_COMMIT..."

# Clean up any existing directory (for example an empty submodule checkout)
if [ -d "$KYS_PATH" ] || [ -f "$KYS_PATH" ]; then
  rm -rf "$KYS_PATH"
fi
mkdir -p "$(dirname "$KYS_PATH")"

TEMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT INT HUP TERM

git clone --filter=blob:none "$KYS_REPO" "$TEMP_DIR"
git -C "$TEMP_DIR" fetch --depth 1 origin "$KYS_COMMIT"
git -C "$TEMP_DIR" checkout "$KYS_COMMIT"

if [ ! -f "$TEMP_DIR/package.json" ]; then
  echo "Failed to fetch Kysely: package.json missing after checkout"
  exit 1
fi

mv "$TEMP_DIR" "$KYS_PATH"
trap - EXIT INT HUP TERM
cleanup

echo "Kysely fetched successfully into $KYS_PATH"
