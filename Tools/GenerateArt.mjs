// The effects' art, drawn from scratch: the trail's dot, the cast ring and
// the ring atlas. Supersampled, uncompressed 32-bit TGA with the origin at
// the top left. The addon's icon and minimap glyph (FECIcon, MinimapIcon) are
// drawn apart, in the family's style, and this never touches them; the
// preview draws the game's own pointer, so there's no stand-in arrow either.
// Run from the addon's folder with: node Tools/GenerateArt.mjs
import { writeFileSync } from 'node:fs';

// Draws size x size pixels; sample(x, y) gives [r, g, b, a] (0 to 1) at a
// point, taken ss x ss times a pixel and averaged.
function render(name, size, sample, ss = 4) {
  const data = Buffer.alloc(18 + size * size * 4);
  data[2] = 2; // uncompressed true colour
  data.writeUInt16LE(size, 12);
  data.writeUInt16LE(size, 14);
  data[16] = 32;
  data[17] = 0x28; // 8 alpha bits, top-left origin
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < ss; sy++) {
        for (let sx = 0; sx < ss; sx++) {
          const c = sample(x + (sx + .5) / ss, y + (sy + .5) / ss);
          r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3];
        }
      }
      const offset = 18 + (y * size + x) * 4;
      const byte = v => Math.max(0, Math.min(255, Math.round(v * 255)));
      if (a > 0) { r /= a; g /= a; b /= a; }
      data[offset] = byte(b);
      data[offset + 1] = byte(g);
      data[offset + 2] = byte(r);
      data[offset + 3] = byte(a / (ss * ss));
    }
  }
  writeFileSync(new URL(`../Media/${name}.tga`, import.meta.url), data);
}

const CLEAR = [0, 0, 0, 0];
const WHITE = [1, 1, 1, 1];

// The trail's dot: soft, brightest in the middle.
render('TrailDot', 32, (x, y) => {
  const r = Math.hypot(x - 16, y - 16) / 16;
  return [1, 1, 1, Math.pow(Math.max(0, 1 - r * r), 2)];
});

// The cast ring: a thin band near the edge.
render('CastRing', 256, (x, y) => {
  const r = Math.hypot(x - 128, y - 128) / 128;
  return r >= .88 && r <= .98 ? WHITE : CLEAR;
});

// The ring atlas: 8 by 8 cells of 128 pixels, each a ring 120 pixels across;
// cell k is (k + 1) / 128 of that across thick (Style.lua's RingCell).
render('Rings', 1024, (x, y) => {
  const column = Math.floor(x / 128), row = Math.floor(y / 128);
  const k = row * 8 + column;
  const r = Math.hypot(x - column * 128 - 64, y - row * 128 - 64);
  const width = (k + 1) * 120 / 128;
  return r <= 60 && r >= 60 - width ? WHITE : CLEAR;
});

console.log('Drew TrailDot, CastRing and Rings.');
