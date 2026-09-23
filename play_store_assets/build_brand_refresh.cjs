const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('E:/code/glimpse-web/node_modules/sharp');

const root = __dirname;
const out = path.join(root, 'brand-refresh');
const fonts = path.join(root, 'fonts');

async function text(text, font, file, color, left, top) {
  return { left, top, input: await sharp({ text: {
    text: `<span foreground="${color}">${text}</span>`, font,
    fontfile: path.join(fonts, file), rgba: true, dpi: 72,
  }}).png().toBuffer() };
}

async function banner(width, height, filename) {
  const scale = width / 1024;
  // Store cards may center-crop the 1024x500 artwork to a narrower ratio.
  const isStore = width === 1024;
  const textLeft = isStore ? 112 : 60;
  const headlineSize = isStore ? 52 : 57;
  const mascotWidth = isStore ? 210 : 240;
  const layers = [
    await text('Glimpse', `Instrument Sans Bold ${40 * scale}`, 'InstrumentSans.ttf', '#172019', Math.round(textLeft * scale), Math.round(76 * scale)),
    await text('Save links.', `Newsreader ${headlineSize * scale}`, 'Newsreader.ttf', '#172019', Math.round(textLeft * scale), Math.round(177 * scale)),
    await text('Keep the knowledge.', `Newsreader ${headlineSize * scale}`, 'Newsreader.ttf', '#48624D', Math.round(textLeft * scale), Math.round(241 * scale)),
    await text('AI bookmark manager', `Instrument Sans ${22 * scale}`, 'InstrumentSans.ttf', '#586056', Math.round((textLeft + 3) * scale), Math.round(330 * scale)),
    { left: Math.round((isStore ? 704 : 725) * scale), top: Math.round(140 * scale), input: await sharp(path.join(root, '../assets/mascot/home.webp')).trim().resize({ width: Math.round(mascotWidth * scale), height: Math.round(295 * scale), fit: 'inside' }).png().toBuffer() },
  ];
  await sharp({ create: { width, height, channels: 3, background: '#F5F4ED' } }).composite(layers).flatten({ background: '#F5F4ED' }).removeAlpha().png().toFile(path.join(out, filename));
}

async function main() {
  await fs.mkdir(out, { recursive: true });
  await banner(1024, 500, 'feature_graphic-v7.png');
  if (process.argv.includes('--store-only')) {
    const file = path.join(out, 'feature_graphic-v7.png');
    const info = await sharp(file).metadata();
    if (info.width !== 1024 || info.height !== 500 || info.hasAlpha) throw new Error('Invalid store export');
    await fs.copyFile(file, path.join(root, 'final', 'feature_graphic-v7.png'));
    await sharp(file).extract({ left: 68, top: 0, width: 888, height: 500 }).resize(356, 200).png().toFile(path.join(out, 'feature_graphic-v7-crop-preview.png'));
    console.log('Verified 1024x500 RGB PNG; wrote a 16:9 crop preview.');
    return;
  }
  await banner(1200, 630, 'opengraph-image.png');
  await sharp(path.join(out, 'opengraph-image.png')).jpeg({ quality: 95 }).toFile(path.join(out, 'og-image.jpg'));
  for (const [size, filename] of [[64, 'icon.png'], [180, 'apple-icon.png']]) {
    const mark = await sharp(path.join(root, '../assets/mascot/home.webp')).trim().resize(size - 12, size - 12, { fit: 'inside' }).png().toBuffer();
    await sharp({ create: { width: size, height: size, channels: 3, background: '#D5E2CE' } }).composite([{ input: mark, gravity: 'centre' }]).removeAlpha().png().toFile(path.join(out, filename));
  }
  for (const filename of ['feature_graphic-v7.png', 'opengraph-image.png', 'icon.png', 'apple-icon.png']) {
    const info = await sharp(path.join(out, filename)).metadata();
    console.log(`${filename}: ${info.width}x${info.height}, ${info.channels} channels`);
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
