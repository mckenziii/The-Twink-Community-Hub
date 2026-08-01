#!/usr/bin/env python3
"""Generate animations/list.lua — the manifest twinkhub Reanimation reads to
discover every animation in this repo's /animations folder.

Run from the repo root:  python genAnimManifest.py
Then commit + push so the raw GitHub URL resolves.
"""
import os
import urllib.parse

REPO = os.path.dirname(os.path.abspath(__file__))
ANIM_DIR = os.path.join(REPO, "animations")
BASE = ("https://raw.githubusercontent.com/mckenziii/"
        "The-Twink-Community-Hub/refs/heads/main/animations/")
MANIFEST_NAME = "list.lua"


def esc_key(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    files = sorted(
        f for f in os.listdir(ANIM_DIR)
        if f.lower().endswith(".lua") and f != MANIFEST_NAME
    )
    rows = []
    for f in files:
        name = f[:-4]  # strip .lua for the display name / dict key
        url = BASE + urllib.parse.quote(f, safe="")
        rows.append('\t["%s"] = "%s",' % (esc_key(name), url))

    manifest = (
        "-- Auto-generated animation manifest for twinkhub Reanimation.\n"
        "-- Maps display name -> raw GitHub URL for every file in /animations.\n"
        "-- Regenerate with genAnimManifest.py after adding/removing animations.\n"
        "return {\n" + "\n".join(rows) + "\n}\n"
    )
    out = os.path.join(ANIM_DIR, MANIFEST_NAME)
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(manifest)
    print("Wrote %d animations to animations/%s" % (len(files), MANIFEST_NAME))


if __name__ == "__main__":
    main()
