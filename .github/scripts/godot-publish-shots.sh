#!/usr/bin/env bash
# Publishes screenshots (as compact JPEGs) to an orphan branch for easy viewing.
set -euo pipefail
src="$1"
branch="$2"
token="$3"
if [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
  echo "no screenshots"
  exit 0
fi
dir=$(mktemp -d)
for f in "$src"/*.png; do
  base=$(basename "${f%.png}")
  if command -v convert >/dev/null; then
    convert "$f" -quality 84 "$dir/$base.jpg" || cp "$f" "$dir/"
  else
    cp "$f" "$dir/"
  fi
done
cd "$dir"
git init -q -b "$branch"
git config user.name "github-actions"
git config user.email "github-actions@users.noreply.github.com"
git add .
git commit -q -m "Screenshots from ${GITHUB_SHA::7} [skip ci]"
git push -f -q "https://x-access-token:${token}@github.com/${GITHUB_REPOSITORY}.git" "$branch"
