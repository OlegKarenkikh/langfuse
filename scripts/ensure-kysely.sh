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
rm -rf "$KYS_PATH"
mkdir -p "$(dirname "$KYS_PATH")"
git clone "$KYS_REPO" "$KYS_PATH"
git -C "$KYS_PATH" checkout "$KYS_COMMIT"
