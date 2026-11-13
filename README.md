# Wallpaper Engine Workshop tab for KDE Plasma

Adds a **Workshop** tab to Plasma's wallpaper settings (the Wallpaper Engine for KDE plugin), next to the
wallpapers you're already subscribed to. Search/browse the Steam Workshop with tri-state tag filters
(e.g. exclude Anime), subscribe with one click, and pick the wallpaper once Steam has downloaded it.

## Install
Needs [wallpaper-engine-kde-plugin](https://github.com/catsout/wallpaper-engine-kde-plugin) (`paru -S wallpaper-engine-kde-plugin-git`) and Wallpaper Engine in Steam.
```bash
git clone https://github.com/Blake-McCullough/wallpaper-engine-search-kde-plugin && cd wallpaper-engine-search-kde-plugin && ./install.sh
```
Then: right-click desktop → Configure Desktop and Wallpaper → Wallpaper Engine → **Workshop**.
Re-run `install.sh` after the upstream plugin updates (it keeps a patched user copy; the system plugin is untouched; delete `~/.local/share/plasma/wallpapers/com.github.catsout.wallpaperEngineKde` to undo).

## How it works
- `wallpaper-workshop` (Python helper in `~/.local/bin`) scrapes the Workshop and talks to Steam; the QML tab calls it.
- **Subscribe** opens the item in your Steam client (already signed in); click Subscribe there. The tab notices when Steam has downloaded it and offers "Use as wallpaper".
- Optional one-click mode: "Sign in for one-click" opens a Steam login window once (only the login cookie is stored in `~/.local/share/wallpaper-workshop`, mode 600). Needs `python-pyqt6-webengine`.
- **Experiment:** `experiments/steamworks_subscribe.py ID` tries subscribing through the running Steam client via the Steamworks API (what Wallpaper Engine does), with no login. Run it and send the output; if it works it becomes the default.
- Optional: Steam Web API key support exists in the helper query (`api_key`).

## Tests
`python3 -I tests/t_page.py` (offscreen QML test with a stubbed Plasma DataSource). Plasma 6 only. License: GPL-2.0-or-later (patches upstream's GPL plugin UI).
