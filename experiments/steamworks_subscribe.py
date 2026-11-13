#!/usr/bin/env python3
"""
EXPERIMENT (option 2): subscribe to a Workshop item through the *running Steam client* using the Steamworks API,
the same way Wallpaper Engine itself does it. No web login.  usage: steamworks_subscribe.py WORKSHOP_ID [path/to/libsteam_api.so]

Needs: Steam running + signed in, an account that owns Wallpaper Engine, and a libsteam_api.so (any native Steam game ships one).
Prints diagnostics at every step so we can see what Linux/Flatpak Steam allows.
"""
import ctypes, glob, os, sys, time
from pathlib import Path

APPID = "431960"
wid = int(sys.argv[1])
os.environ["SteamAppId"] = os.environ["SteamGameId"] = APPID      # pretend to be Wallpaper Engine

def find_lib():
    if len(sys.argv) > 2:
        return sys.argv[2]
    roots = [Path.home() / ".local/share/Steam", Path.home() / ".steam/steam",
             Path.home() / ".var/app/com.valvesoftware.Steam/.local/share/Steam"]
    for r in roots:
        for pat in ("steamapps/common/*/**/libsteam_api.so", "**/libsteam_api.so"):
            for f in glob.glob(str(r / pat), recursive=True):
                return f
    return None

lib_path = find_lib()
print("libsteam_api:", lib_path)
if not lib_path:
    sys.exit("No libsteam_api.so found. Pass one as the 2nd argument (copy it from any native Linux Steam game).")
lib = ctypes.CDLL(lib_path)

lib.SteamAPI_Init.restype = ctypes.c_bool
print("SteamAPI_Init:", end=" ")
ok = lib.SteamAPI_Init()
print(ok)
if not ok:
    sys.exit("Init failed: is Steam running and signed in? (Flatpak Steam can't be reached from outside its sandbox.)")

ugc = None
for v in range(30, 10, -1):
    name = f"SteamAPI_SteamUGC_v{v:03d}"
    fn = getattr(lib, name, None)
    if fn is not None:
        fn.restype = ctypes.c_void_p
        ugc = fn()
        print("using", name, "->", hex(ugc or 0))
        if ugc:
            break
if not ugc:
    sys.exit("Couldn't get the ISteamUGC interface from this libsteam_api.so.")

lib.SteamAPI_ISteamUGC_SubscribeItem.restype = ctypes.c_uint64
lib.SteamAPI_ISteamUGC_SubscribeItem.argtypes = [ctypes.c_void_p, ctypes.c_uint64]
lib.SteamAPI_ISteamUGC_GetItemState.restype = ctypes.c_uint32
lib.SteamAPI_ISteamUGC_GetItemState.argtypes = [ctypes.c_void_p, ctypes.c_uint64]

call = lib.SteamAPI_ISteamUGC_SubscribeItem(ugc, wid)
print("SubscribeItem call handle:", call)
for i in range(60):
    lib.SteamAPI_RunCallbacks()
    st = lib.SteamAPI_ISteamUGC_GetItemState(ugc, wid)       # bit0 subscribed, bit2 installed, bit3 needs update, bit4 downloading
    if i % 10 == 0:
        print(f"item state flags: {st:#x}")
    if st & 1:
        print("SUBSCRIBED (state", hex(st) + ")")
        break
    time.sleep(0.2)
else:
    print("No subscribed flag after 12s; Steam may still be processing.")
lib.SteamAPI_Shutdown()
