# Glimpse Play Store screenshot set

Eight portrait screenshots are rendered at **1440 × 2560 px (9:16)** as 24-bit RGB PNGs. The live Android app captures are preserved inside restrained Material 3 marketing surfaces; the device status bar is removed and the clipboard URL on the capture screen is replaced with a neutral example.

The recommended **1024 × 500 px** Play Store feature graphic is `final/feature_graphic-v3.png`. It uses Glimpse's exact Instrument Sans and Newsreader typography, a muted stone/sage palette, five small library icons, and a reduced mascot signature. Earlier concepts remain available for comparison.

## Story order

1. **Capture** — Save a link, optionally add a note, and let Glimpse recover the context.
2. **Library** — Keep social posts, videos, articles, and other sources in one calm home.
3. **Briefs** — Turn a saved link into a summary, key takeaways, and useful recommendations.
4. **Ask** — Ask across the library or focus on one saved item.
5. **Library** — Automatically find books, movies, places, and more while keeping personal collections manual.
6. **Interests** — See recurring and growing patterns across the library.
7. **Search** — Search titles, tags, notes, and summaries, with filters.
8. **Rediscover** — Bring back a small daily set and weekly/monthly recaps.

## Suggested Play Console alt text

1. Glimpse capture screen with a link, optional collection and note fields, and a Capture button.
2. Glimpse home showing Rediscover, source filters, recent saves, and Ask Glimpse.
3. Movie-recommendation details with a summary, five key takeaways, and titles worth watching.
4. Ask Glimpse screen with prompts for questions grounded in 173 saved links.
5. Library overview finding books, movies, and places automatically above custom collections.
6. Interests screen grouping saved links into movies, software and AI, books, spirituality, and growth.
7. Search results for movies across saved YouTube and Instagram links with tags and filters.
8. Rediscover screen with a stable daily set of past saves and a weekly recap.

## Rebuild

Run:

```powershell
C:\Users\pc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe play_store_assets\build_play_store_images.py
```

Final upload assets are in `play_store_assets/final/`. `preview-grid.jpg` is a review-only contact sheet.

To rebuild the feature graphic:

```powershell
C:\Users\pc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe play_store_assets\build_feature_graphic.py
```

To rebuild the refined version:

```powershell
C:\Users\pc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe play_store_assets\build_feature_graphic_v2.py
```

To rebuild the clean icon-led version:

```powershell
C:\Users\pc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe play_store_assets\build_feature_graphic_v3.py
```
