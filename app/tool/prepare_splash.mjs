// Run from app/: node tool/prepare_splash.mjs "path/to/Figma-export.json"
// Keep the original Figma export; these are renderer-specific app assets.
import { readFileSync, writeFileSync } from 'node:fs';

if (!process.argv[2]) throw new Error('Provide the original Figma export path.');
const animation = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const screenName = 'Splash — animated (hero)';
const backgroundNames = new Set([screenName, 'Green flood', 'Glow']);
const centerX = animation.w / 2;
function shiftX(layer, delta) {
  if (layer.ks.p.a === 0) layer.ks.p.k[0] += delta;
  else for (const key of layer.ks.p.k) {
    if (key.s) key.s[0] += delta;
    if (key.e) key.e[0] += delta;
  }
}
if (animation.w !== 390 || animation.h !== 844 ||
    !animation.layers.some(layer => layer.nm === screenName)) {
  throw new Error('Expected the original 390 × 844 splash export.');
}

// Remove only the prototype's phone chrome, with name AND position checks.
const chrome = new Map([
  ['354.5,23', 'Rectangle'], ['355.5,23', 'Rectangle'],
  ['327,23', 'icon/wifi'], ['312.5,25.25', 'Rectangle'],
  ['307.5,26.5', 'Rectangle'], ['302.5,27.75', 'Rectangle'],
  ['297.5,29', 'Rectangle'], ['49,25.5', '9:41'],
]);
animation.layers = animation.layers.filter(layer =>
  layer.ks?.p?.a !== 0 || chrome.get(layer.ks.p.k.join(',')) !== layer.nm);

for (const layer of animation.layers) {
  // Flutter clips the viewport once. Per-layer rounded viewport masks incur
  // many offscreen compositing passes and belong to the Figma device mockup.
  if (layer.masksProperties) {
    layer.masksProperties = layer.masksProperties.filter(mask => mask.nm !== screenName);
    layer.hasMask = layer.masksProperties.length > 0;
    if (!layer.hasMask) delete layer.masksProperties;
  }
  if (layer.ty === 5) {
    for (const key of layer.t.d.k) {
      const text = key.s;
      // Lottie 3.3.1's glyph path uses tracking/10 in pixels, whereas its font
      // path also scales by size/100. Match that scale for embedded outlines.
      text.tr = Math.round(text.tr * text.s / 100);
      if (layer.nm.startsWith('Wordmark/')) {
        // Point text prevents individual letters wrapping at a rounded width.
        text.sz[0] = 0;
      } else {
        // Preserve the original text centre and baseline, while allowing the
        // real bundled fonts and tracking to fit on one line.
        text.ps[0] = layer.ks.a.k[0] - 175;
        text.sz[0] = 350;
        text.j = 2;
      }
    }
    if (!layer.nm.startsWith('Wordmark/')) {
      const position = layer.ks.p.a === 0 ? layer.ks.p.k : layer.ks.p.k[0].s;
      shiftX(layer, centerX - position[0]);
    }
  }
  if (layer.nm === screenName) {
    for (const group of layer.shapes) {
      for (const shape of group.it ?? []) {
        if (shape.ty === 'rc') shape.r = { a: 0, k: 0 };
      }
    }
  }
}

// Centre the whole staggered wordmark; retain each letter's spacing and Y keys.
const wordmark = animation.layers.filter(layer => layer.nm.startsWith('Wordmark/'));
const extents = wordmark.map(layer => {
  const text = layer.t.d.k[0].s;
  const font = animation.fonts.list.find(font => font.fName === text.f);
  const glyph = animation.chars.find(glyph => glyph.ch === text.t &&
    glyph.fFamily === font.fFamily && glyph.style === font.fStyle);
  const left = layer.ks.p.k[0].s[0] - layer.ks.a.k[0] + text.ps[0];
  return [left, left + glyph.w * text.s / 100];
});
const wordmarkCenter = (Math.min(...extents.map(e => e[0])) + Math.max(...extents.map(e => e[1]))) / 2;
for (const layer of wordmark) shiftX(layer, centerX - wordmarkCenter);
const dots = animation.layers.filter(layer => /^Dot [123]$/.test(layer.nm));
const dotsCenter = dots.reduce((sum, layer) => sum + layer.ks.p.k[0], 0) / dots.length;
for (const layer of dots) shiftX(layer, centerX - dotsCenter);

function compositionFor(background) {
  const result = structuredClone(animation);
  result.layers = result.layers.filter(layer => backgroundNames.has(layer.nm) === background);
  const used = new Set(result.layers.map(layer => layer.refId).filter(Boolean));
  for (let size = -1; size !== used.size;) {
    size = used.size;
    for (const asset of result.assets) {
      if (used.has(asset.id)) {
        for (const layer of asset.layers ?? []) if (layer.refId) used.add(layer.refId);
      }
    }
  }
  result.assets = result.assets.filter(asset => used.has(asset.id));
  if (background) {
    delete result.chars;
    delete result.fonts;
  }
  return result;
}

for (const [file, background] of [
  ['consentlink-splash.json', false],
  ['consentlink-splash-background.json', true],
]) {
  writeFileSync(`assets/animations/${file}`, JSON.stringify(compositionFor(background)));
}
