#!/bin/bash
# Sync this repo's plugin source into the live Omarchy plugin dir.
# This repo is the source of truth; the plugin dir is a deployed copy.
# Never edit files in the plugin dir by hand.
#
# The bar widget drives ~/Projects/vox-workspace/local-llm/llm.sh (start|stop|restart).
#
# Usage: install.sh [--enable] [--no-lint]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$REPO_DIR/plugin"
MANIFEST="$PLUGIN_SRC/manifest.json"

[[ -f $MANIFEST ]] || { echo "install: missing $MANIFEST" >&2; exit 1; }

PLUGIN_ID="$(jq -r '.id' "$MANIFEST")"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

ENABLE=0
LINT=1
for arg in "$@"; do
  case "$arg" in
    --enable) ENABLE=1 ;;
    --no-lint) LINT=0 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "install: unknown option $arg" >&2; exit 1 ;;
  esac
done

# Validate the source before replacing a working installation.
echo "==> Validating manifest"
omarchy plugin validate "$PLUGIN_SRC"
if (( LINT )) && [[ -x $REPO_DIR/scripts/lint.sh ]]; then
  "$REPO_DIR/scripts/lint.sh" "$PLUGIN_SRC"
fi

echo "==> Installing $PLUGIN_ID -> $PLUGIN_DEST"
rm -rf "$PLUGIN_DEST"
mkdir -p "$PLUGIN_DEST"
# Copy only the code the shell loads: manifest plus every QML component.
cp "$PLUGIN_SRC/manifest.json" "$PLUGIN_DEST/"
find "$PLUGIN_SRC" -maxdepth 1 -name '*.qml' -exec cp {} "$PLUGIN_DEST/" \;
# Copy any nested QML modules / assets, but never a .git dir.
if [[ -d $PLUGIN_SRC/lib ]]; then cp -R "$PLUGIN_SRC/lib" "$PLUGIN_DEST/lib"; fi

echo "==> Rescanning shell plugins"
omarchy-shell shell rescanPlugins >/dev/null

if (( ENABLE )); then
  echo "==> Enabling $PLUGIN_ID"
  omarchy plugin enable "$PLUGIN_ID" || true
fi

echo "==> Done. Listed as:"
omarchy plugin list | grep -E "ID|$PLUGIN_ID" || true
