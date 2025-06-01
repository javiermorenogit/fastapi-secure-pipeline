#!/usr/bin/env bash
set -e

VERSION="9.2.0"
CACHE_DIR="$HOME/.cache/dependency-check"
BIN="$CACHE_DIR/dependency-check/bin/dependency-check.sh"

if [[ ! -f "$BIN" ]]; then
  mkdir -p "$CACHE_DIR"
  curl -sL \
    "https://github.com/jeremylong/DependencyCheck/releases/download/v$VERSION/dependency-check-${VERSION}-release.zip" \
    -o "$CACHE_DIR/dc.zip"
  unzip -q "$CACHE_DIR/dc.zip" -d "$CACHE_DIR"
fi

"$BIN" "$@"