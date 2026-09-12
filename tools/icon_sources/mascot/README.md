# Glimpse mascot branding

The approved artwork is shared by dev and production. Run:

```powershell
flutter test --no-pub --flavor dev tools/render_splash_start_test.dart
python tools/generate_mascot_assets.py
flutter build apk --debug --flavor dev --no-pub
```

`color.png` is the full-width, shorter light-sage URL card launcher on evergreen.
`monochrome.png` is its dedicated transparent themed-icon mask.
`home.png` is the ivory mascot with the sage card, used by Home, brand imagery,
and the native/Flutter splash. `collections.png`, `interests.png`, and
`search.png` are the folder, floating topic tiles, and magnifying-glass variants.
The brand mark in `assets/mascot/brand-mark.svg` is traced from the approved
monochrome launcher alpha by `tools/generate_mascot_mark.py`. It preserves the
original silhouette, hand outlines, and diagonal chain. The same exporter
updates `assets/glimpse.svg`, `assets/mono.svg`, the Android notification vector,
and all five white-alpha notification bitmap densities.

Sources were edited with the built-in image generation tool. The final Home
prompt preserved the exact mascot and card geometry, recolored only the card
light sage (#CBDAC3), retained ivory hands and two gold strokes, and requested
transparent output. The baked-in checkerboard was removed locally with user
authorization, and the cutouts checked on light and dark backgrounds.

The canonical exporter writes Android main resources (inherited by both
flavors), shared 512px WebP artwork, iOS icon/splash resources, and compatibility
source assets. The older generator entry points delegate to it. Notification
glyphs are regenerated from that same monochrome source. Do not reintroduce flavor-specific artwork copies.

The launcher tile's outer preview margin is excluded and the tile is placed in
the 72dp viewport of the 108dp adaptive layer. The themed mask retains its
approved 92% optical scale. Native splash exports use 58% artwork on a 288dp
canvas; StartupReveal matches that geometry for its 750ms one-way rise.
The native splash uses `splash_start.png`, exported from the exact Flutter
starting pose, so the mascot never appears fully raised before the animation.
Reduced motion bypasses the animation and the destination stays mounted.
