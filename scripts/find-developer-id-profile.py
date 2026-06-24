#!/usr/bin/env python3
"""Locate a Mac Developer ID provisioning profile for noortech.Zirn."""

from __future__ import annotations

import glob
import os
import plistlib
import subprocess
import sys

BUNDLE_ID = os.environ.get("ZIRN_BUNDLE_ID", "noortech.Zirn")
PROFILE_DIR = os.path.expanduser("~/Library/Developer/Xcode/UserData/Provisioning Profiles")


def decode_profile(path: str) -> dict:
    raw = subprocess.check_output(["security", "cms", "-D", "-i", path])
    return plistlib.loads(raw)


def profile_matches(plist: dict) -> bool:
    if not plist.get("ProvisionsAllDevices"):
        return False

    entitlements = plist.get("Entitlements", {})
    app_id = entitlements.get("com.apple.application-identifier", "")
    if BUNDLE_ID not in app_id:
        return False

    groups = entitlements.get("keychain-access-groups", [])
    if not groups:
        return False

    team_prefix = app_id.split(".", 1)[0] + "."
    for group in groups:
        if BUNDLE_ID in group:
            return True
        if group == f"{team_prefix}*":
            return True

    return False


def main() -> int:
    override = os.environ.get("PROVISIONING_PROFILE", "").strip()
    if override:
        if os.path.isfile(override):
            print(override)
            return 0
        print(f"PROVISIONING_PROFILE not found: {override}", file=sys.stderr)
        return 1

    candidates: list[tuple[str, str]] = []
    for path in glob.glob(os.path.join(PROFILE_DIR, "*.provisionprofile")):
        try:
            plist = decode_profile(path)
        except (subprocess.CalledProcessError, plistlib.InvalidFileException, ValueError):
            continue
        if profile_matches(plist):
            candidates.append((plist.get("Name", ""), path))

    if not candidates:
        return 1

    candidates.sort(key=lambda item: item[0])
    print(candidates[0][1])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
