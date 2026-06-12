#!/usr/bin/env python3
"""Write Finder .DS_Store for a DMG volume (no AppleScript required).

Requires: pip install ds-store mac-alias
"""

from __future__ import annotations

import argparse
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate DMG .DS_Store layout.")
    parser.add_argument("mount_dir", help="Mounted DMG root path")
    parser.add_argument("--window-x", type=int, required=True)
    parser.add_argument("--window-y", type=int, required=True)
    parser.add_argument("--window-width", type=int, default=512)
    parser.add_argument("--window-height", type=int, default=384)
    parser.add_argument("--icon-size", type=int, default=128)
    parser.add_argument("--text-size", type=int, default=13)
    parser.add_argument(
        "--background",
        default="background.png",
        help="Background filename inside .background/ (default: background.png)",
    )
    parser.add_argument("--app-name", default="Zirn.app")
    parser.add_argument("--app-x", type=int, default=340)
    parser.add_argument("--app-y", type=int, default=230)
    parser.add_argument("--applications-x", type=int, default=90)
    parser.add_argument("--applications-y", type=int, default=230)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        from ds_store import DSStore
        from mac_alias import Alias
    except ImportError:
        print(
            "error: install dependencies with: python3 -m pip install ds-store mac-alias",
            file=sys.stderr,
        )
        return 1

    import os

    mount_dir = os.path.abspath(args.mount_dir)
    background_path = os.path.join(mount_dir, ".background", args.background)
    if not os.path.isfile(background_path):
        print(f"error: missing background at {background_path}", file=sys.stderr)
        return 1

    bounds_string = (
        f"{{{{{args.window_x}, {args.window_y}}}, "
        f"{{{args.window_width}, {args.window_height}}}}}"
    )

    bwsp = {
        "ShowStatusBar": False,
        "WindowBounds": bounds_string,
        "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
        "SidebarWidth": 180,
        "ShowTabView": False,
        "ShowToolbar": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
    }

    alias = Alias.for_file(background_path)

    icvp = {
        "viewOptionsVersion": 1,
        "backgroundType": 2,
        "backgroundImageAlias": alias.to_bytes(),
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "arrangeBy": "none",
        "showIconPreview": False,
        "showItemInfo": False,
        "labelOnBottom": True,
        "textSize": float(args.text_size),
        "iconSize": float(args.icon_size),
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
    }

    ds_store_path = os.path.join(mount_dir, ".DS_Store")
    with DSStore.open(ds_store_path, "w+") as store:
        store["."]["vSrn"] = ("long", 1)
        store["."]["bwsp"] = bwsp
        store["."]["icvp"] = icvp
        store["."]["icvl"] = ("type", b"icnv")
        store[args.app_name]["Iloc"] = (args.app_x, args.app_y)
        store["Applications"]["Iloc"] = (args.applications_x, args.applications_y)

    print(f"wrote {ds_store_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
