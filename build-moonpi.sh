#!/usr/bin/env bash
set -euo pipefail
# build-moonpi.sh
# Builds the moonpi .deb package.
# Usage:
#   ./build-moonpi.sh

LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load personal defaults from .env if present (see .env.example)
if [[ -f "$LOCAL_DIR/.env" ]]; then
  source "$LOCAL_DIR/.env"
fi

export DEBFULLNAME="${DEBFULLNAME:-POONpirate}"
export DEBEMAIL="${DEBEMAIL:-kellyzekilla@hotmail.com}"

#— Dependency check -----------------------------------------------------------
for pkg in devscripts debhelper dos2unix lintian; do
  if ! dpkg -l "$pkg" &>/dev/null; then
    echo "📦 Installing missing dependency: $pkg…"
    sudo apt-get install -y "$pkg"
  fi
done

#— Line endings and permissions -----------------------------------------------
find "$LOCAL_DIR" -type f -exec dos2unix {} +

# Strip executable from everything, then restore only what needs it
find "$LOCAL_DIR" -type f | xargs chmod -x
chmod +x "$LOCAL_DIR/usr/bin/moonpi"
chmod +x "$LOCAL_DIR/usr/bin/moonpi-safe"
chmod +x "$LOCAL_DIR/pull-moonpi.sh"
chmod +x "$LOCAL_DIR/build-moonpi.sh"
for f in postinst preinst prerm rules; do
  [[ -f "$LOCAL_DIR/debian/$f" ]] && chmod +x "$LOCAL_DIR/debian/$f"
  [[ -f "$LOCAL_DIR/DEBIAN/$f" ]] && chmod +x "$LOCAL_DIR/DEBIAN/$f"
done

#— Normalize debian/ ----------------------------------------------------------
# dpkg-buildpackage requires lowercase 'debian/' — rename if it landed as 'DEBIAN/'
if [[ -d "$LOCAL_DIR/DEBIAN" && ! -d "$LOCAL_DIR/debian" ]]; then
  echo "Renaming DEBIAN/ → debian/ for dpkg-buildpackage…"
  mv "$LOCAL_DIR/DEBIAN" "$LOCAL_DIR/debian"
fi

perl -i -0777 -pe 's/\z/\n/ unless /\n\z/' "$LOCAL_DIR/debian/rules"

#— Changelog ------------------------------------------------------------------
cd "$LOCAL_DIR"

echo
echo "📝 Changelog time!"
echo "   1) Edit debian/changelog manually"
echo "   2) Skip changelog editing"
read -p "Choose [1–2]: " ch_choice

case "$ch_choice" in
  1)
    PACKAGE=$(awk '/^Source:/ { print $2; exit }' debian/control)
    VERSION=$(
      [[ -s debian/changelog ]] \
        && dpkg-parsechangelog --show-field Version \
        || echo "1.0"
    )

    if [[ ! -s debian/changelog ]]; then
      echo "📝 Creating debian/changelog for $PACKAGE $VERSION"
      dch --create \
          --newversion "$VERSION" \
          --package "$PACKAGE" \
          --distribution bookworm \
          "Automated build via build-moonpi.sh ($(date '+%Y-%m-%d %H:%M'))"
    else
      echo "📝 Updating debian/changelog for $PACKAGE"
      dch \
          --distribution bookworm \
          "Automated build via build-moonpi.sh ($(date '+%Y-%m-%d %H:%M'))"
    fi
    ;;
  *)
    echo "Skipping changelog edits."
    if [[ ! -s debian/changelog ]]; then
      PACKAGE=$(awk '/^Source:/ { print $2; exit }' debian/control)
      echo "⚠️  No changelog found — creating initial entry for $PACKAGE…"
      dch --create \
          --newversion "1.0" \
          --package "$PACKAGE" \
          --distribution bookworm \
          "Initial release."
    fi
    ;;
esac

#— Build ----------------------------------------------------------------------
dpkg-buildpackage -us -uc

CHANGES_FILE=$(ls -t ../*.changes 2>/dev/null | head -n1)
if [[ -n "$CHANGES_FILE" ]]; then
  echo "🔍 Running lintian on ${CHANGES_FILE}..."
  lintian "$CHANGES_FILE"
else
  echo "⚠️  No .changes file found to lint."
fi
