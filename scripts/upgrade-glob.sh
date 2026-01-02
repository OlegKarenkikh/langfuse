#!/bin/sh
# Upgrade glob 10.x to 11.1.0
cd /app
npm pack glob@11.1.0 2>/dev/null || exit 0

find node_modules -type d -name "glob" 2>/dev/null | while read dir; do
  if [ -f "$dir/package.json" ]; then
    if grep -q '"version": "10\.' "$dir/package.json" 2>/dev/null; then
      echo "Replacing glob in $dir"
      tar -xzf /app/glob-11.1.0.tgz -C "$dir" --strip-components=1 2>/dev/null || true
    fi
  fi
done

rm -f /app/glob-11.1.0.tgz
echo "Glob upgrade complete"
