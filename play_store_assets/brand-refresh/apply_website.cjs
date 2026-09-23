const fs = require('node:fs');
const path = require('node:path');
const web = 'E:/code/glimpse-web';
const stage = __dirname;

function update(relative, transform) {
  const file = path.join(web, relative);
  const before = fs.readFileSync(file, 'utf8');
  const after = transform(before);
  if (before === after) throw new Error(`No expected change for ${relative}`);
  fs.writeFileSync(file, after);
}

update('lib/site-config.ts', source => source
  .replace('  name: "Glimpse",', '  name: "Glimpse",\n  tagline: "Save links. Keep the knowledge.",')
  .replace('ogImage: "/opengraph-image"', 'ogImage: "/opengraph-image.png"')
  .replace('Glimpse — Saved Once. Remembered When It Matters.', 'Glimpse: AI Bookmark Manager')
  .replace('alt: "Glimpse — saved links that return when they matter"', 'alt: `${siteConfig.name} — ${siteConfig.tagline}`'));
update('components/HeroSection.tsx', source => source
  .replace('import HeroActions from "./HeroActions";', 'import HeroActions from "./HeroActions";\nimport { siteConfig } from "@/lib/site-config";')
  .replace('<h1>Saved once. Remembered when it matters.</h1>', '<h1>{siteConfig.tagline}</h1>'));
for (const relative of ['app/icon.png', 'app/apple-icon.png', 'app/opengraph-image.png', 'public/og-image.jpg']) {
  fs.copyFileSync(path.join(stage, path.basename(relative)), path.join(web, relative));
}
// Static metadata image replaces the previous generated route, not a second route.
fs.unlinkSync(path.join(web, 'app/opengraph-image.tsx'));
fs.writeFileSync(path.join(web, 'app/opengraph-image.alt.txt'), 'Glimpse — Save links. Keep the knowledge.\n');
console.log('Updated website hero, metadata, favicon, Apple icon, and social image.');
