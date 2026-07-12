"""Generate Glimpse's checked-in Material Symbols variable-font subset.

Flutter's icon tree shaker currently corrupts the variation tables in the
Material Symbols variable font. This script makes a small subset with
FontTools instead. It discovers every Symbols.<name> reference under lib/ so
the checked-in font cannot silently drift away from the Dart source.

Requires FontTools: python -m pip install fonttools
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from urllib.parse import unquote, urlparse

from fontTools import subset
from fontTools.ttLib import TTFont


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_NAME = "material_symbols_icons"
SYMBOL_REFERENCE = re.compile(r"\bSymbols\.([A-Za-z0-9_]+)")
SYMBOL_DECLARATION = re.compile(
    r"static const IconData\s+(\w+)\s*=\s*"
    r"IconData\(0x([0-9a-fA-F]+),\s*"
    r"fontFamily:\s*'MaterialSymbolsRounded'",
    re.MULTILINE,
)


def _package_root() -> Path:
    package_config = PROJECT_ROOT / ".dart_tool" / "package_config.json"
    if package_config.exists():
        config = json.loads(package_config.read_text(encoding="utf-8"))
        for package in config["packages"]:
            if package["name"] != PACKAGE_NAME:
                continue
            root_uri = package["rootUri"]
            if root_uri.startswith("file:"):
                uri_path = unquote(urlparse(root_uri).path)
                if os.name == "nt":
                    uri_path = uri_path.lstrip("/")
                return Path(uri_path)
            return (package_config.parent / root_uri).resolve()

    pub_cache = Path.home() / "AppData" / "Local" / "Pub" / "Cache" / "hosted" / "pub.dev"
    candidates = sorted(pub_cache.glob(f"{PACKAGE_NAME}-*"), reverse=True)
    if candidates:
        return candidates[0]
    raise FileNotFoundError(f"Could not locate the {PACKAGE_NAME} package")


def _used_symbol_names() -> set[str]:
    names: set[str] = set()
    for source in (PROJECT_ROOT / "lib").rglob("*.dart"):
        names.update(SYMBOL_REFERENCE.findall(source.read_text(encoding="utf-8")))
    if not names:
        raise RuntimeError("No Material Symbols references found under lib/")
    return names


def main() -> None:
    package_root = _package_root()
    symbols_source = (package_root / "lib" / "symbols.dart").read_text(encoding="utf-8")
    rounded_codepoints = {
        name: int(codepoint, 16)
        for name, codepoint in SYMBOL_DECLARATION.findall(symbols_source)
    }

    used_names = _used_symbol_names()
    missing = sorted(used_names - rounded_codepoints.keys())
    if missing:
        raise RuntimeError(
            "Only rounded Material Symbols can use the bundled font; missing: "
            + ", ".join(missing)
        )

    input_font = package_root / "lib" / "fonts" / "MaterialSymbolsRounded.ttf"
    output_font = PROJECT_ROOT / "assets" / "fonts" / "GlimpseMaterialSymbolsRounded.ttf"
    output_font.parent.mkdir(parents=True, exist_ok=True)

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.recalc_timestamp = False

    font = TTFont(input_font, recalcTimestamp=False)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes={rounded_codepoints[name] for name in used_names})
    subsetter.subset(font)
    font.save(output_font)

    print(
        f"Wrote {output_font.relative_to(PROJECT_ROOT)} "
        f"({output_font.stat().st_size:,} bytes, {len(used_names)} symbols)"
    )


if __name__ == "__main__":
    main()
