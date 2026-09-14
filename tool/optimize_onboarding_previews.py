"""Lossless format conversion for Flutter-rendered onboarding captures."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent.parent
source = root / '.dart_tool' / 'onboarding' / 'previews'
target = root / 'assets' / 'onboarding' / 'previews'
target.mkdir(parents=True, exist_ok=True)
for locale in ('en', 'de', 'es', 'fr', 'pt', 'ja'):
    for theme in ('light', 'dark'):
        for chapter in range(4, 6):
            parts = {2: (1, 2, 3), 3: (1, 2, 3, 4), 5: (1, 2)}.get(chapter, (0,))
            for part in parts:
                name = f'{locale}_{theme}_{chapter}_{part}'
                with Image.open(source / f'{name}.png') as image:
                    image.save(target / f'{name}.webp', lossless=True, method=6)
print('Wrote 36 lossless onboarding previews.')
