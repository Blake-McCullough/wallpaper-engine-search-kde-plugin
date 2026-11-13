#!/usr/bin/env python3
"""Adds the Workshop tab to a copy of the Wallpaper Engine for KDE plugin.  usage: apply.py PLUGIN_DIR WORKSHOP_QML"""
import shutil, sys
from pathlib import Path

plugin, page_qml = Path(sys.argv[1]), Path(sys.argv[2])
ui = plugin / "contents" / "ui"
cfg = ui / "config.qml"
text = cfg.read_text()

if "WorkshopPage" not in text:
    def swap(old, new):
        global text
        if text.count(old) != 1:
            sys.exit(f"apply.py: could not find expected code in config.qml ({old.strip()[:40]!r}); "
                     "the upstream plugin changed, please open an issue.")
        text = text.replace(old, new)

    swap('''        PlasmaComponents.TabButton {
            text: "Wallpapers"
        }
''', '''        PlasmaComponents.TabButton {
            text: "Wallpapers"
        }
        PlasmaComponents.TabButton {
            text: "Workshop"
        }
''')
    swap("implicitWidth: font.pixelSize*8 * 3", "implicitWidth: font.pixelSize*8 * 4")
    swap('''        WallpaperPage {
            id: wallpaperPage
        }
''', '''        WallpaperPage {
            id: wallpaperPage
        }

        WorkshopPage {
            libraryPath: root.cfg_SteamLibraryPath
            currentId: root.cfg_WallpaperWorkShopId
            onUseWallpaper: (id, source) => {
                root.cfg_WallpaperWorkShopId = id;
                root.cfg_WallpaperSource = source;
            }
        }
''')
    cfg.write_text(text)

shutil.copy(page_qml, ui / "page" / "WorkshopPage.qml")
qd = ui / "page" / "qmldir"
q = qd.read_text()
if "WorkshopPage" not in q:
    qd.write_text(q.rstrip("\n") + "\nWorkshopPage WorkshopPage.qml\n")
print("Workshop tab added to", plugin)
