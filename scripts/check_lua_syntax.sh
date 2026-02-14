#!/usr/bin/env bash
set -euo pipefail

if ! command -v luac >/dev/null 2>&1; then
  echo "luac not found; install lua5.1 or lua to run syntax checks" >&2
  exit 1
fi

files=(AutoJunkDestroyer.lua Migration.lua Core.lua UI.lua Minimap.lua Shard.lua Commands.lua)
while IFS= read -r f; do
  files+=("$f")
done < <(find Locales -maxdepth 1 -type f -name '*.lua' | sort)

for f in "${files[@]}"; do
  luac -p "$f"
done

echo "Lua syntax checks passed for ${#files[@]} files"
