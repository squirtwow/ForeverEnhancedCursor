// The two pictures of Forever Enhanced Cooldown Manager in the General page's
// More from Squirt: its Layout page and its bars in game. This addon's own
// small copies of the screenshots on that addon's CurseForge page, so they
// show without it. Each is read from that addon's Screenshots folder (left as
// it is: the player's name stays blurred exactly as there), scaled to 512
// across with its shape kept, and kept at the top of a 512 by 512 texture
// (the game's textures are a power of two across), its last row repeated
// below it so the smaller copies the game makes for the thumbnails don't
// darken its foot. Uncompressed 32-bit TGA, bottom row first like the icons.
// Window.lua shows the top part (SHOTS: its width and height) and draws its
// thumbnails from the same texture.
// Run from the addon's folder with: node Tools/GenerateShots.mjs [screenshots folder]
import { readFileSync, writeFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const SIZE = 512;
export const SHOTS = [
  { source: 'layout-page.png', name: 'FECMShotLayout.tga' },
  { source: 'in-game-hunter.png', name: 'FECMShotInGame.tga' },
];

// An 8-bit, non-interlaced PNG (RGB or RGBA) as rows of RGB bytes; anything
// see-through is laid on black (the screenshots are solid).
export function readPng(data) {
  if (data.readUInt32BE(0) !== 0x89504e47) throw new Error('not a PNG');
  let at = 8, width, height, depth, kind, interlace;
  const idat = [];
  while (at < data.length) {
    const length = data.readUInt32BE(at), type = data.toString('latin1', at + 4, at + 8);
    const body = data.subarray(at + 8, at + 8 + length);
    if (type === 'IHDR') {
      width = body.readUInt32BE(0); height = body.readUInt32BE(4);
      depth = body[8]; kind = body[9]; interlace = body[12];
    } else if (type === 'IDAT') idat.push(body);
    else if (type === 'IEND') break;
    at += 12 + length;
  }
  if (depth !== 8 || (kind !== 2 && kind !== 6) || interlace !== 0) throw new Error('only 8-bit RGB or RGBA, not interlaced');
  const channels = kind === 6 ? 4 : 3, stride = width * channels;
  const raw = inflateSync(Buffer.concat(idat));
  const rows = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? rows[y * stride + x - channels] : 0;
      const b = y > 0 ? rows[(y - 1) * stride + x] : 0;
      const c = x >= channels && y > 0 ? rows[(y - 1) * stride + x - channels] : 0;
      let value = line[x];
      if (filter === 1) value += a;
      else if (filter === 2) value += b;
      else if (filter === 3) value += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        value += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      } else if (filter !== 0) throw new Error(`unknown PNG filter ${filter}`);
      rows[y * stride + x] = value & 255;
    }
  }
  const rgb = new Float64Array(width * height * 3);
  for (let p = 0; p < width * height; p++) {
    const alpha = channels === 4 ? rows[p * 4 + 3] / 255 : 1;
    for (let k = 0; k < 3; k++) rgb[p * 3 + k] = rows[p * channels + k] * alpha;
  }
  return { width, height, rgb };
}

// Catmull-Rom, widened by the scale when shrinking: sharp text, little
// ringing, and the same bytes on every machine (no sines).
function weight(t) {
  t = Math.abs(t);
  if (t < 1) return 1.5 * t * t * t - 2.5 * t * t + 1;
  if (t < 2) return -0.5 * t * t * t + 2.5 * t * t - 4 * t + 2;
  return 0;
}
// One pass along one direction: from `from` samples to `to`, `count` lines.
function pass(input, from, to, count, index) {
  const output = new Float64Array(to * count * 3);
  const scale = from / to, spread = Math.max(1, scale);
  for (let i = 0; i < to; i++) {
    const centre = (i + 0.5) * scale - 0.5;
    const first = Math.floor(centre - 2 * spread) + 1, last = Math.ceil(centre + 2 * spread) - 1;
    const taps = [];
    let total = 0;
    for (let j = first; j <= last; j++) {
      const w = weight((j - centre) / spread);
      if (w === 0) continue;
      taps.push([Math.min(from - 1, Math.max(0, j)), w]);
      total += w;
    }
    for (let line = 0; line < count; line++) {
      for (let k = 0; k < 3; k++) {
        let sum = 0;
        for (const [j, w] of taps) sum += input[index(line, j) * 3 + k] * w;
        output[index.out(line, i) * 3 + k] = sum / total;
      }
    }
  }
  return output;
}
export function scale(image, width, height) {
  const across = (line, j) => line * image.width + j;
  across.out = (line, i) => line * width + i;
  const wide = pass(image.rgb, image.width, width, image.height, across);
  const down = (line, j) => j * width + line;
  down.out = (line, i) => i * width + line;
  return { width, height, rgb: pass(wide, image.height, height, width, down) };
}

// The picture at the top of a SIZE square, its last row repeated below it.
export function toTga(image) {
  const data = Buffer.alloc(18 + SIZE * SIZE * 4);
  data[2] = 2; // uncompressed true colour
  data.writeUInt16LE(SIZE, 12);
  data.writeUInt16LE(SIZE, 14);
  data[16] = 32;
  data[17] = 8; // 8 alpha bits, bottom row first
  const byte = v => Math.max(0, Math.min(255, Math.round(v)));
  for (let y = 0; y < SIZE; y++) {
    const from = Math.min(y, image.height - 1); // the picture's row shown at y (top first)
    const at = 18 + (SIZE - 1 - y) * SIZE * 4; // the file keeps the bottom row first
    for (let x = 0; x < SIZE; x++) {
      const p = (from * image.width + Math.min(x, image.width - 1)) * 3;
      data[at + x * 4] = byte(image.rgb[p + 2]);
      data[at + x * 4 + 1] = byte(image.rgb[p + 1]);
      data[at + x * 4 + 2] = byte(image.rgb[p]);
      data[at + x * 4 + 3] = 255;
    }
  }
  return data;
}

// Each screenshot as the game draws it: SIZE across, its height to keep its shape.
export function build(folder) {
  return SHOTS.map(shot => {
    const image = readPng(readFileSync(join(folder, shot.source)));
    const height = Math.round(image.height * SIZE / image.width);
    return { ...shot, width: SIZE, height, data: toTga(scale(image, SIZE, height)) };
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const addon = fileURLToPath(new URL('../', import.meta.url));
  const folder = process.argv[2] || join(addon, '..', 'ForeverEnhancedCooldownManager', 'Screenshots');
  for (const shot of build(folder)) {
    writeFileSync(join(addon, 'Media', shot.name), shot.data);
    console.log(`Drew ${shot.name}: ${shot.width} by ${shot.height} at the top of ${SIZE} by ${SIZE}.`);
  }
}
