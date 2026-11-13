#!/usr/bin/env bash
# Adds a "Workshop" tab (search + subscribe) to Plasma's Wallpaper Engine wallpaper settings.
# Works from a git checkout or piped from curl. Re-run it after the Wallpaper Engine plugin updates.
set -e
REPO="Blake-McCullough/wallpaper-engine-search-kde-plugin"
ID=com.github.catsout.wallpaperEngineKde
DEST="$HOME/.local/share/plasma/wallpapers/$ID"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo .)"
RAW="https://github.com/$REPO/releases/latest/download"

fetch() {  # fetch <name> <dest>
  if [ -f "$DIR/$3" ]; then cp "$DIR/$3" "$2"; else curl -fsSL "$RAW/$1" -o "$2"; fi
}

echo "==> Looking for the Wallpaper Engine plugin"
SRC=""
for d in /usr/share/plasma/wallpapers/$ID /usr/lib/qt6/../../share/plasma/wallpapers/$ID; do
  [ -d "$d" ] && SRC="$d" && break
done
if [ -z "$SRC" ]; then
  echo "!! Install it first:  paru -S wallpaper-engine-kde-plugin-git   (then log out and in), and re-run this."
  exit 1
fi

echo "==> Installing Qt WebEngine (only used for the Steam sign-in window)"
sudo pacman -S --needed --noconfirm python-pyqt6 python-pyqt6-webengine

echo "==> Installing helper"
mkdir -p "$HOME/.local/bin"
fetch wallpaper-workshop "$HOME/.local/bin/wallpaper-workshop" wallpaper-workshop
chmod 755 "$HOME/.local/bin/wallpaper-workshop"

echo "==> Adding the Workshop tab (user copy of the plugin; the system one is untouched)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fetch apply.py "$T/apply.py" plugin/apply.py
fetch WorkshopPage.qml "$T/WorkshopPage.qml" plugin/contents/ui/page/WorkshopPage.qml
rm -rf "$DEST"; mkdir -p "$(dirname "$DEST")"; cp -r "$SRC" "$DEST"
python3 "$T/apply.py" "$DEST" "$T/WorkshopPage.qml"

echo "Done. Open: Desktop right-click -> Configure Desktop and Wallpaper -> Wallpaper Engine -> Workshop tab."
echo "(If the tab doesn't show, run: plasmashell --replace &  or log out and in.)"
