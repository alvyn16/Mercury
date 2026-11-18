#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="${1:-}"
RAW_TARGET_DIR="${2:-$HOME/.local/share/appimages}"
# Expand tilde if provided
TARGET_DIR="${RAW_TARGET_DIR/#\~/$HOME}"
APPS_DIR="$HOME/.local/share/applications"
ICONS_BASE="$HOME/.local/share/icons/hicolor"

die() {
  local msg="$1"
  jq -n --arg error "$msg" '{success: false, error: $error}'
  exit 1
}

if [[ -z "$SOURCE_FILE" || ! -f "$SOURCE_FILE" ]]; then
  die "Source file does not exist: ${SOURCE_FILE:-<empty>}"
fi

# Ensure executable permissions on source
chmod +x "$SOURCE_FILE" 2>/dev/null || true

# Validate file format
FILE_TYPE=$(file -b "$SOURCE_FILE" 2>/dev/null || true)
if ! echo "$FILE_TYPE" | grep -qiE 'ELF|AppImage'; then
  die "Selected file is not an ELF or AppImage executable ($FILE_TYPE)."
fi

TMP_DIR=$(mktemp -d /tmp/mercury.XXXXXX)
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$TMP_DIR"

# Attempt selective extraction of metadata and icons first
"$SOURCE_FILE" --appimage-extract "*.desktop" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract ".DirIcon" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract "*.png" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract "*.svg" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract "usr/share/icons/*" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract "usr/share/applications/*" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract "share/icons/*" >/dev/null 2>&1 || true
"$SOURCE_FILE" --appimage-extract "share/applications/*" >/dev/null 2>&1 || true

SQUASH_ROOT="$TMP_DIR/squashfs-root"

# Find desktop file and verify it is readable
DESKTOP_SRC=""
if [[ -d "$SQUASH_ROOT" ]]; then
  # Look for a valid .desktop file (resolving symlinks)
  while IFS= read -r f; do
    if [[ -f "$f" ]]; then
      DESKTOP_SRC="$f"
      break
    fi
  done < <(find "$SQUASH_ROOT" -name "*.desktop" 2>/dev/null)
fi

# If selective extraction failed or left broken symlinks, do full extract
if [[ -z "$DESKTOP_SRC" || ! -f "$DESKTOP_SRC" ]]; then
  "$SOURCE_FILE" --appimage-extract >/dev/null 2>&1 || true
  while IFS= read -r f; do
    if [[ -f "$f" ]]; then
      DESKTOP_SRC="$f"
      break
    fi
  done < <(find "$SQUASH_ROOT" -name "*.desktop" 2>/dev/null)
fi

if [[ -z "$DESKTOP_SRC" || ! -f "$DESKTOP_SRC" ]]; then
  die "No readable .desktop entry found inside AppImage."
fi

# Extract metadata fields from .desktop
APP_NAME=$(grep -m1 '^Name=' "$DESKTOP_SRC" | cut -d= -f2- || true)
if [[ -z "$APP_NAME" ]]; then
  APP_NAME=$(basename "$SOURCE_FILE" | sed -E 's/\.(appimage|AppImage)$//I')
fi

APP_COMMENT=$(grep -m1 '^Comment=' "$DESKTOP_SRC" | cut -d= -f2- || true)
[[ -z "$APP_COMMENT" ]] && APP_COMMENT="$APP_NAME Application"

APP_CATEGORIES=$(grep -m1 '^Categories=' "$DESKTOP_SRC" | cut -d= -f2- || true)
[[ -z "$APP_CATEGORIES" ]] && APP_CATEGORIES="Utility;"

APP_WMCLASS=$(grep -m1 '^StartupWMClass=' "$DESKTOP_SRC" | cut -d= -f2- || true)
[[ -z "$APP_WMCLASS" ]] && APP_WMCLASS="$APP_NAME"

APP_MIMETYPE=$(grep -m1 '^MimeType=' "$DESKTOP_SRC" | cut -d= -f2- || true)

# Create safe and sanitized app ID for filenames
APP_ID=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_.-' '-' | sed 's/^-//;s/-$//')
[[ -z "$APP_ID" ]] && APP_ID="app_$(date +%s)"

# Deploy binary
mkdir -p "$TARGET_DIR"
DEST_BIN="$TARGET_DIR/${APP_ID}.AppImage"
cp -f "$SOURCE_FILE" "$DEST_BIN"
chmod +x "$DEST_BIN"

# Deploy Icons with original resolution preservation
mkdir -p "$ICONS_BASE/scalable/apps" \
         "$ICONS_BASE/512x512/apps" \
         "$ICONS_BASE/256x256/apps" \
         "$ICONS_BASE/128x128/apps" \
         "$ICONS_BASE/64x64/apps" \
         "$ICONS_BASE/48x48/apps" \
         "$ICONS_BASE/32x32/apps"

ICON_NAME="appimage_${APP_ID}"
INSTALLED_ICON_PATH=""

# 1. Scalable SVG icons
SVG_ICON=$(find "$SQUASH_ROOT" -type f -name "*.svg" 2>/dev/null | head -n 1 || true)
if [[ -n "$SVG_ICON" && -f "$SVG_ICON" ]]; then
  cp -f "$SVG_ICON" "$ICONS_BASE/scalable/apps/${ICON_NAME}.svg"
  INSTALLED_ICON_PATH="$ICONS_BASE/scalable/apps/${ICON_NAME}.svg"
fi

# 2. .DirIcon (often 512x512 or 256x256)
if [[ -e "$SQUASH_ROOT/.DirIcon" ]]; then
  RESOLVED_DIRICON=$(readlink -f "$SQUASH_ROOT/.DirIcon" || echo "$SQUASH_ROOT/.DirIcon")
  if [[ -f "$RESOLVED_DIRICON" ]]; then
    cp -f "$RESOLVED_DIRICON" "$ICONS_BASE/512x512/apps/${ICON_NAME}.png"
    [[ -z "$INSTALLED_ICON_PATH" ]] && INSTALLED_ICON_PATH="$ICONS_BASE/512x512/apps/${ICON_NAME}.png"
  fi
fi

# 3. Hierarchy icons from squashfs (e.g. 512x512, 256x256, 128x128, etc.)
for size in 512x512 256x256 128x128 64x64 48x48 32x32; do
  size_png=$(find "$SQUASH_ROOT" -type f -path "*/${size}/*" -name "*.png" 2>/dev/null | head -n 1 || true)
  if [[ -n "$size_png" && -f "$size_png" ]]; then
    cp -f "$size_png" "$ICONS_BASE/${size}/apps/${ICON_NAME}.png"
    [[ -z "$INSTALLED_ICON_PATH" ]] && INSTALLED_ICON_PATH="$ICONS_BASE/${size}/apps/${ICON_NAME}.png"
  fi
done

# 4. Fallback to any PNG icon found
if [[ -z "$INSTALLED_ICON_PATH" ]]; then
  ANY_PNG=$(find "$SQUASH_ROOT" -type f -name "*.png" 2>/dev/null | head -n 1 || true)
  if [[ -n "$ANY_PNG" && -f "$ANY_PNG" ]]; then
    cp -f "$ANY_PNG" "$ICONS_BASE/256x256/apps/${ICON_NAME}.png"
    INSTALLED_ICON_PATH="$ICONS_BASE/256x256/apps/${ICON_NAME}.png"
  fi
fi

ICON_KEY="${ICON_NAME}"
if [[ -z "$INSTALLED_ICON_PATH" ]]; then
  ICON_KEY="application-x-executable"
fi

# Generate XDG Desktop Entry
mkdir -p "$APPS_DIR"
DESKTOP_DEST="$APPS_DIR/appimage_${APP_ID}.desktop"

cat <<DESKTOP_ENTRY_EOF > "$DESKTOP_DEST"
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec="${DEST_BIN}" %U
Icon=${ICON_KEY}
Comment=${APP_COMMENT}
Categories=${APP_CATEGORIES}
Terminal=false
StartupWMClass=${APP_WMCLASS}
X-AppImage-Original-Exec="${DEST_BIN}"
X-AppImage-Created-By=Mercury
DESKTOP_ENTRY_EOF

if [[ -n "$APP_MIMETYPE" ]]; then
  echo "MimeType=${APP_MIMETYPE}" >> "$DESKTOP_DEST"
fi

# Refresh desktop databases immediately
update-desktop-database "$APPS_DIR" 2>/dev/null || true
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f "$ICONS_BASE" 2>/dev/null || true
fi

# Emit JSON result
jq -n \
  --arg success "true" \
  --arg appId "$APP_ID" \
  --arg name "$APP_NAME" \
  --arg binaryPath "$DEST_BIN" \
  --arg desktopPath "$DESKTOP_DEST" \
  --arg iconName "$ICON_KEY" \
  --arg iconPath "$INSTALLED_ICON_PATH" \
  '{
    success: ($success == "true"),
    appId: $appId,
    name: $name,
    binaryPath: $binaryPath,
    desktopPath: $desktopPath,
    iconName: $iconName,
    iconPath: $iconPath
  }'
