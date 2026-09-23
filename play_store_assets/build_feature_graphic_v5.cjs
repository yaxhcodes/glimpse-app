const fs = require('node:fs');
const path = require('node:path');
const sharp = require('E:/code/glimpse-web/node_modules/sharp');

const root = __dirname;
const output = path.join(root, 'final', 'feature_graphic-v5.png');
const sans = path.join(root, 'fonts', 'InstrumentSans.ttf');
const serif = path.join(root, 'fonts', 'Newsreader.ttf');

async function textLayer(text, font, fontfile, color, left, top) {
  const input = await sharp({ text: {
    text: `<span foreground="${color}">${text}</span>`,
    font, fontfile, rgba: true, dpi: 72,
  }}).png().toBuffer();
  return { input, left, top };
}

async function main() {
  // Reuse the original mascot pixels; no generated reconstruction.
  const mascot = await sharp(path.join(root, '..', 'assets', 'mascot', 'home.webp'))
    .trim().resize({ width: 286, height: 330, fit: 'inside' }).png().toBuffer();
  const layers = [
    await textLayer('Glimpse', 'Instrument Sans Bold 40', sans, '#172019', 60, 64),
    await textLayer('Save something', 'Newsreader 55', serif, '#172019', 60, 179),
    await textLayer('worth keeping', 'Newsreader 55', serif, '#48624D', 60, 243),
    await textLayer('Your links, ideas, and discoveries.', 'Instrument Sans 21', sans, '#586056', 63, 339),
    { input: mascot, left: 678, top: 117 },
  ];
  await sharp({ create: { width: 1024, height: 500, channels: 3, background: '#F5F4ED' } })
    .composite(layers).flatten({ background: '#F5F4ED' }).removeAlpha().png().toFile(output);
  const info = await sharp(output).metadata();
  if (info.width !== 1024 || info.height !== 500 || info.hasAlpha) throw new Error('Invalid feature graphic export');
  console.log(JSON.stringify({ output, width: info.width, height: info.height, channels: info.channels, bytes: fs.statSync(output).size }));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
