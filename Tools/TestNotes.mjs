// What's new in the game (Notes.lua) must say what CHANGELOG.txt says, version
// by version, nothing unused ships in Media/, and the footer's heart, the
// addon's icons and the cooldown manager's pictures are drawn right, and
// Tools/GenerateArt.mjs and Tools/GenerateShots.mjs only draw their own art.
// Run with: node Tools/TestNotes.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, mkdtemp, mkdir, copyFile, rm } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const read = name => readFile(new URL(`../${name}`, import.meta.url), 'utf8');
const STRING = '"((?:[^"\\\\]|\\\\.)*)"'; // a Lua string in double quotes
const unquote = text => text.replace(/\\(.)/g, '$1');

// The ns.NOTES table: each version's sections, then their bullets.
function gameNotes(lua) {
  const lines = lua.split(/\r?\n/);
  const start = lines.findIndex(line => line.trim() === 'ns.NOTES = {');
  const end = lines.findIndex((line, i) => i > start && line === '}');
  assert.ok(start >= 0 && end > start, 'ns.NOTES found in Notes.lua');
  const entries = [];
  for (const line of lines.slice(start + 1, end)) {
    let match;
    if ((match = line.match(new RegExp(`^\\s*version = ${STRING},\\s*$`)))) {
      entries.push({ version: unquote(match[1]), sections: [] });
    } else if ((match = line.match(new RegExp(`^\\s*\\{ ${STRING}, \\{\\s*$`)))) {
      entries.at(-1).sections.push({ title: unquote(match[1]), items: [] });
    } else if ((match = line.match(new RegExp(`^\\s*${STRING},\\s*$`)))) {
      entries.at(-1).sections.at(-1).items.push(unquote(match[1]));
    }
  }
  return entries;
}

// CHANGELOG.txt: "## version", then "### section" and "- bullet" lines.
function changelogNotes(text) {
  const entries = [];
  for (const line of text.split(/\r?\n/)) {
    let match;
    if ((match = line.match(/^## (.+)$/))) entries.push({ version: match[1].trim(), sections: [] });
    else if ((match = line.match(/^### (.+)$/))) entries.at(-1).sections.push({ title: match[1].trim(), items: [] });
    else if ((match = line.match(/^- (.+)$/))) entries.at(-1).sections.at(-1).items.push(match[1].trim());
  }
  return entries;
}

test('What\'s new in the game matches CHANGELOG.txt, version by version', async () => {
  const game = gameNotes(await read('Notes.lua'));
  assert.ok(game.length > 0 && game[0].sections.length > 0, 'notes to show');
  assert.deepEqual(game, changelogNotes(await read('CHANGELOG.txt')));
});

// No version number until Squirt picks one: the first release's notes are
// "Unreleased" until then, and its number once it has one.
test('the first notes wait for their version number, or have one', async () => {
  const first = gameNotes(await read('Notes.lua')).at(-1).version;
  assert.ok(first === 'Unreleased' || /^\d+\.\d+(\.\d+)?$/.test(first), `"${first}" is Unreleased or a version number`);
  const changelog = await read('CHANGELOG.txt');
  assert.match(changelog, new RegExp(`^## ${first.replace(/\./g, '\\.')}$`, 'm'), 'CHANGELOG.txt heads it the same');
});

test('only the newest notes can wait for their version number', async () => {
  gameNotes(await read('Notes.lua')).forEach((entry, index) => {
    if (index === 0 && entry.version === 'Unreleased') return;
    assert.match(entry.version, /^\d+\.\d+(\.\d+)?$/, `"${entry.version}" is a version number`);
  });
});

// Tour.lua's steps, the full tour's then What's new's: each one's title and
// the version lines on it ([line, number, placeholder] for each).
async function tourSteps() {
  const lua = (await read('Tour.lua')).replace(/\r\n/g, '\n');
  const steps = [];
  for (const list of ['STEPS', 'NEWS']) {
    const start = lua.indexOf(`\nlocal ${list} = {\n`);
    assert.ok(start >= 0, `${list} found in Tour.lua`);
    const block = lua.slice(start, lua.indexOf('\n}\n', start));
    for (const step of block.split(/\n    \{\n/).slice(1)) {
      const title = step.match(/^        title = "([^"]+)",$/m);
      steps.push({
        list,
        title: title ? title[1] : step.trim().split('\n')[1],
        versions: [...step.matchAll(/^        version = (?:"([^"]+)"|(ns\.UNRELEASED)),$/gm)],
      });
    }
  }
  return steps;
}

// -1, 0 or 1 as version a is older than, the same as or newer than b, part by
// part as numbers ("1.10" after "1.9", "1.1" is "1.1.0").
function compareVersions(a, b) {
  const x = a.split('.').map(Number), y = b.split('.').map(Number);
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const difference = (x[i] ?? 0) - (y[i] ?? 0);
    if (difference) return Math.sign(difference);
  }
  return 0;
}

// Tour.lua: each step says the version it arrived in, so What's new can tour
// just an update's steps. A numbered one must be a version with notes; the
// next update's wait as ns.UNRELEASED until the release gives them its
// number. The basics: the menu, each page in turn, then where to find it all.
test('every tour step has the version it arrived in', async () => {
  const released = new Set(gameNotes(await read('Notes.lua')).map(entry => entry.version));
  const steps = await tourSteps();
  for (const step of steps) {
    assert.equal(step.versions.length, 1, `one version on: ${step.title}`);
    const [, number, placeholder] = step.versions[0];
    if (!placeholder) assert.ok(released.has(number), `"${number}" has notes in Notes.lua`);
  }
  assert.deepEqual(steps.filter(step => step.list === 'STEPS').map(step => step.title), ['The menu', 'The trail', 'Colours',
    'Rings', 'Profiles', 'Auto-switch', "That's the basics"], 'the basics, in order');
});

// A release never shows steps still waiting for their number, so it gives
// them its number when its notes get it. Once the newest notes are a release
// newer than every numbered step, a step still waiting was left behind.
test('tour steps waiting for their number get it with the notes', async () => {
  const newest = gameNotes(await read('Notes.lua'))[0].version;
  const steps = await tourSteps();
  const waiting = steps.filter(step => step.versions[0]?.[2]).map(step => step.title);
  const numbered = steps.map(step => step.versions[0]?.[1]).filter(Boolean);
  if (!/^\d+(\.\d+)*$/.test(newest) || waiting.length === 0) return;
  assert.ok(numbered.some(number => compareVersions(number, newest) >= 0),
    `${waiting.join(', ')} still wait as ns.UNRELEASED, but the newest notes are ${newest}, newer than every numbered step:`
    + ` give them ${newest} if they shipped in it, or add the next update's notes as Unreleased first`);
});

test('every section has bullets, and none use em dashes', async () => {
  for (const entry of gameNotes(await read('Notes.lua'))) {
    for (const section of entry.sections) {
      assert.ok(section.items.length > 0, `${entry.version} ${section.title} has bullets`);
      for (const item of section.items) assert.doesNotMatch(item, /—/, item);
    }
  }
});

// Needs testing marks only what hasn't been seen working in game. Seen working
// (2026-10-03): the trail and its extras, the cast ring, the highlight while
// looking, Share and Auto-switch. Not yet: a mount you list. The changelog (and
// so What's new, checked above), README and the CurseForge description agree.
test('Needs testing only on a mount you list, in the changelog, README and the description', async () => {
  for (const name of ['CHANGELOG.txt', 'README.md', 'Tools/CurseForgeDescription.html']) {
    const text = (await read(name)).replace(/\s+/g, ' ');
    const marks = [...text.matchAll(/needs testing/gi)].map(m => text.slice(Math.max(0, m.index - 40), m.index + 14));
    assert.equal(marks.length, 1, `${name}: Needs testing once, on the mount only: ${marks.join(' | ')}`);
    assert.match(text, /a mount you list \(Needs testing\)/, `${name}: on a mount you list`);
  }
});

// A TGA as the game reads the addon's textures: uncompressed 32-bit true
// colour with 8 alpha bits, nothing after the pixels; bottom row first (the
// heart, the tour's arrow and the icons), or top row first (the art
// Tools/GenerateArt.mjs draws), as its header says.
async function tga(name, size, top = false) {
  const data = await readFile(new URL(`../Media/${name}`, import.meta.url));
  assert.deepEqual([data[2], data.readUInt16LE(12), data.readUInt16LE(14), data[16], data[17]], [2, size, size, 32, top ? 0x28 : 8],
    `${name}: uncompressed true colour, ${size}x${size}, 32 bits a pixel, 8 of them alpha, ${top ? 'top' : 'bottom'} row first`);
  assert.equal(data.length, 18 + size * size * 4, `${name}: nothing after the pixels`);
  return data;
}

// The footer's credit draws its heart from Media: white so the accent can
// tint it, the right way up (TGA rows start at the bottom unless the header
// says not).
test('the footer heart is a white 32x32 TGA, point down', async () => {
  const name = (await read('Window.lua')).match(/local HEART = "([^"]+)"/)?.[1];
  assert.equal(name, 'Heart.tga', 'Window.lua names the heart');
  const size = 32;
  const data = await tga(name, size);
  const widths = [];
  let white = true;
  for (let row = 0; row < size; row++) {
    let solid = 0;
    for (let col = 0; col < size; col++) {
      const at = 18 + (row * size + col) * 4;
      if (data[at] !== 255 || data[at + 1] !== 255 || data[at + 2] !== 255) white = false;
      if (data[at + 3] > 127) solid++;
    }
    widths.push(solid);
  }
  assert.ok(white, 'white everywhere, so the tint is the accent');
  const widest = widths.indexOf(Math.max(...widths));
  assert.ok(widest > size / 2 && widths[1] < widths[widest] / 4, 'the lobes at the top, the point at the bottom');
  assert.ok(widths[0] === 0 && widths[size - 1] === 0, 'clear of the top and bottom edges');
});

// The tour's arrow (2026-10-02): near white so the accent can tint it, a
// triangle pointing up (TGA rows start at the bottom): wide at the bottom,
// a point at the top. Tour.lua turns it to face each side.
test('the tour arrow is a white 32x32 TGA, pointing up', async () => {
  assert.match(await read('Tour.lua'), /ns\.MEDIA \.\. "TourArrow\.tga"/, 'Tour.lua draws it');
  const size = 32;
  const data = await tga('TourArrow.tga', size);
  const widths = [];
  let white = true;
  for (let row = 0; row < size; row++) {
    let solid = 0;
    for (let col = 0; col < size; col++) {
      const at = 18 + (row * size + col) * 4;
      if (data[at + 3] > 127) {
        solid++;
        if (data[at] < 250 || data[at + 1] < 250 || data[at + 2] < 250) white = false;
      }
    }
    widths.push(solid);
  }
  assert.ok(white, 'white where it shows, so the tint is the accent');
  assert.ok(widths[0] >= widths[size / 2] && widths[size / 2] > widths[size - 3], 'widest at the bottom, narrowing upwards');
  assert.equal(widths[size - 1], 0, 'a point at the top');
});

// The icon and the minimap glyph, redrawn on purpose in the family's style
// (2026-10-02; recoloured purple, design kept, 2026-10-05): a dark rounded tile with a purple border, a purple pointer
// with its trail of dots and a purple bar along the foot (128), and the
// pointer and dots alone on clear (64). Bottom row first, like the heart.
// Both are final art, pinned below; Tools/GenerateArt.mjs never draws them,
// so it can't put the old ones back.
const purple = (data, at) => data[at + 3] > 200 && data[at] > 200 && data[at + 2] > 140 && data[at + 2] < 210 && data[at + 1] > 90 && data[at + 1] < 160; // BGRA: FECM's purple 176, 125, 240
function purpleIn(data, size, row) {
  let count = 0;
  for (let col = 0; col < size; col++) if (purple(data, 18 + (row * size + col) * 4)) count++;
  return count;
}
// The purple in each quarter as the game shows the picture (top row first,
// whichever way the file keeps its rows), skipping inset pixels round the
// edge (the icon's border).
function quarters(data, size, inset) {
  const topFirst = (data[17] & 0x20) !== 0;
  const q = { tl: 0, tr: 0, bl: 0, br: 0 };
  for (let y = inset; y < size - inset; y++) {
    for (let x = inset; x < size - inset; x++) {
      const at = 18 + ((topFirst ? y : size - 1 - y) * size + x) * 4;
      if (purple(data, at)) q[(y < size / 2 ? 't' : 'b') + (x < size / 2 ? 'l' : 'r')]++;
    }
  }
  return q;
}
// The pointer on the right and its dots rising to it from the left: neither
// mirrored nor upside down, whatever the header says.
function rightWayRound(name, q) {
  const seen = JSON.stringify(q);
  assert.ok(q.tr + q.br > 2 * (q.tl + q.bl), `${name}: the pointer on the right, the dots on the left (${seen})`);
  assert.ok(q.tl > 2 * q.bl, `${name}: the dots rising to the pointer, so the right way up (${seen})`);
}

test('the addon icon and minimap glyph are TGAs the game can read, in the family style', async () => {
  const icon = await tga('FECIcon.tga', 128);
  assert.equal(icon[18 + 3], 0, 'the icon\'s corners are clear, round the rounded tile');
  assert.equal(icon[18 + (64 * 128 + 64) * 4 + 3], 255, 'and its middle solid');
  let dark = 0, lit = 0;
  for (let at = 18; at < icon.length; at += 4) {
    if (icon[at + 3] === 255 && icon[at] < 40 && icon[at + 1] < 40 && icon[at + 2] < 40) dark++;
    if (purple(icon, at)) lit++;
  }
  assert.ok(dark > 128 * 128 / 2, 'a dark tile');
  assert.ok(lit > 500, 'with purple on it');
  // The bar along the foot: rows come bottom first, so it's in the first quarter.
  const bar = Math.max(...[...Array(32).keys()].map(row => purpleIn(icon, 128, row) - purpleIn(icon, 128, 127 - row)));
  assert.ok(bar >= 25, 'the purple bar at the foot, the right way up');
  rightWayRound('FECIcon.tga', quarters(icon, 128, 20));
  const glyph = await tga('MinimapIcon.tga', 64);
  assert.equal(glyph[18 + 3], 0, 'the glyph sits on a clear background');
  let glyphLit = 0;
  for (let at = 18; at < glyph.length; at += 4) if (purple(glyph, at)) glyphLit++;
  assert.ok(glyphLit > 200, 'a purple pointer and dots');
  rightWayRound('MinimapIcon.tga', quarters(glyph, 64, 0));
});

// Final art, byte for byte, so neither is redrawn, flipped or swapped by
// accident. A redraw on purpose puts its new hashes here.
test('the addon icon and minimap glyph are the final art', async () => {
  const pinned = {
    'FECIcon.tga': '426548b403a3a124512fa873b78127dbf02b390c',
    'MinimapIcon.tga': '07cbf95dccecd34fc8d876aa72f233920e338b1a',
  };
  for (const [name, sha1] of Object.entries(pinned)) {
    const data = await readFile(new URL(`../Media/${name}`, import.meta.url));
    assert.equal(createHash('sha1').update(data).digest('hex'), sha1, `${name} is the final art`);
  }
});

// More from Squirt (the General page) shows Squirt's other Forever Enhanced
// addons with their own icons: this addon's copies, so each shows without
// that addon, byte for byte as each ships it (2026-10-03). A new icon there
// puts its new hash here.
test("More from Squirt's icons are each addon's own, copied as it ships", async () => {
  const copies = {
    'FECMIcon.tga': '4e62d7e24b52be4f41c450c09f8037366c272762',
    'FERFIcon.tga': '0b6a2e762886f804e0232a0ff2b74755828da5a4',
  };
  const window = await read('Window.lua');
  for (const [name, sha1] of Object.entries(copies)) {
    const data = await tga(name, 128);
    assert.equal(createHash('sha1').update(data).digest('hex'), sha1, `${name}: the addon's own icon, unchanged`);
    assert.ok(window.includes(`icon = "${name}"`), `${name}: shown by More from Squirt`);
  }
});

// The two pictures of Forever Enhanced Cooldown Manager in its More from
// Squirt panel (2026-10-03, the user's pick from its CurseForge page: its
// Layout page and its bars in game), made by Tools/GenerateShots.mjs from
// that addon's own screenshots: each scaled to 512 across, shape kept, at the
// top of a 512 square, the player's name still blurred as there. Pinned byte
// for byte, like the icons; a new picture on purpose puts its hash here.
const SHOTS = {
  'FECMShotLayout.tga': { sha1: 'c9beb57181d07e2635a33dd59bfb5e102fd17a13', height: 349, source: 'layout-page.png' },
  'FECMShotInGame.tga': { sha1: 'fedac7f70f77f86114cd459c2e7b354d4de3cb50', height: 392, source: 'in-game-hunter.png' },
};
const SHOT_SOURCES = new URL('../../ForeverEnhancedCooldownManager/Screenshots/', import.meta.url);
// A pixel as the game shows the picture (top row first, whatever the file
// keeps first): [r, g, b, a].
function pixel(data, size, x, y) {
  const at = 18 + (((data[17] & 0x20) !== 0 ? y : size - 1 - y) * size + x) * 4;
  return [data[at + 2], data[at + 1], data[at], data[at + 3]];
}
// How many pixels of a part of the picture (as shown) pass a test.
function count(data, size, x0, y0, x1, y1, test) {
  let n = 0;
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) if (test(pixel(data, size, x, y))) n++;
  return n;
}

test("the cooldown manager's pictures: TGAs the game can read, the final ones, solid", async () => {
  for (const [name, shot] of Object.entries(SHOTS)) {
    const data = await tga(name, 512);
    assert.equal(createHash('sha1').update(data).digest('hex'), shot.sha1, `${name} is the final picture`);
    assert.equal(count(data, 512, 0, 0, 512, 512, p => p[3] !== 255), 0, `${name}: solid everywhere`);
  }
});

// The right way round and in its colours, as the game shows it: the Layout
// page's orange icon at the top left of its title bar (none in the other
// corners); in game, the green health bar over the blue mana bar, both
// across the middle, and the cast bar filling from the left.
test("the cooldown manager's pictures show the right way round, in their colours", async () => {
  const layout = await readFile(new URL('../Media/FECMShotLayout.tga', import.meta.url));
  const orangeish = p => p[0] > 170 && p[1] > 60 && p[1] < 150 && p[2] < 80;
  const h = SHOTS['FECMShotLayout.tga'].height;
  const corners = { tl: count(layout, 512, 0, 0, 30, 30, orangeish), tr: count(layout, 512, 482, 0, 512, 30, orangeish),
    bl: count(layout, 512, 0, h - 30, 30, h, orangeish), br: count(layout, 512, 482, h - 30, 512, h, orangeish) };
  assert.ok(corners.tl > 20 && corners.tr + corners.bl + corners.br === 0, `the icon at the top left only (${JSON.stringify(corners)})`);
  const game = await readFile(new URL('../Media/FECMShotInGame.tga', import.meta.url));
  const green = p => p[1] > 170 && p[0] < 90 && p[2] < 90, blue = p => p[2] > 200 && p[0] < 110 && p[1] < 140;
  const purple = p => p[0] > 130 && p[2] > 180 && p[1] < 170 && p[1] > 90;
  const rows = test => [...Array(392).keys()].filter(y => count(game, 512, 0, y, 512, y + 1, test) > 400);
  const greens = rows(green), blues = rows(blue);
  assert.ok(greens.length >= 20 && blues.length >= 20, `a wide green bar and a wide blue bar (${greens.length}, ${blues.length})`);
  assert.ok(Math.max(...greens) < Math.min(...blues), 'the green bar over the blue one, so the right way up');
  assert.ok(greens[0] > 392 / 4 && blues.at(-1) < 392 * 3 / 5, 'both across the middle');
  const cast = Math.max(...blues) + 25; // the cast bar, just under the blue one
  const left = count(game, 512, 0, cast - 6, 256, cast + 6, purple), right = count(game, 512, 256, cast - 6, 512, cast + 6, purple);
  assert.ok(left > 1000 && right < left / 3, `the cast bar fills from the left, so not mirrored (${left}, ${right})`);
});

// Below each picture, the rest of its square repeats its last row, so the
// game's smaller copies (the thumbnails) don't darken its foot. Window.lua
// shows each at the height made, from the files made.
test("the cooldown manager's pictures fill the top of their square, and Window.lua shows that much", async () => {
  const window = await read('Window.lua');
  for (const [name, shot] of Object.entries(SHOTS)) {
    const data = await readFile(new URL(`../Media/${name}`, import.meta.url));
    const last = shot.height - 1;
    let same = true;
    for (let y = shot.height; y < 512 && same; y++) {
      for (let x = 0; x < 512; x++) if (pixel(data, 512, x, y).join() !== pixel(data, 512, x, last).join()) { same = false; break; }
    }
    assert.ok(same, `${name}: its last row repeated below it`);
    assert.notEqual(count(data, 512, 0, last - 1, 512, last, p => p.join() !== pixel(data, 512, 0, last - 1).join()), 0,
      `${name}: a picture above it, not one colour`);
    assert.match(window, new RegExp(`\\{ file = "${name.replace('.', '\\.')}", height = ${shot.height}, `), `${name}: Window.lua shows ${shot.height} rows`);
  }
  assert.match(window, /^local SHOT_SIZE = 512 /m, 'from a 512 square');
});

// Tools/GenerateShots.mjs, run in a scratch folder on the cooldown manager's
// own screenshots (when that addon is there to read): it draws exactly the two
// pictures as they ship, at the heights Window.lua shows, and nothing else.
test('Tools/GenerateShots.mjs draws the two pictures as they ship', async t => {
  let sources;
  try {
    sources = await readdir(SHOT_SOURCES);
  } catch {
    return t.skip("the cooldown manager's screenshots aren't here to draw from");
  }
  for (const shot of Object.values(SHOTS)) assert.ok(sources.includes(shot.source), `${shot.source} to draw from`);
  const scratch = await mkdtemp(join(tmpdir(), 'fec-shots-'));
  try {
    await mkdir(join(scratch, 'Tools'));
    await mkdir(join(scratch, 'Media'));
    const script = join(scratch, 'Tools', 'GenerateShots.mjs');
    await copyFile(new URL('GenerateShots.mjs', import.meta.url), script);
    execFileSync(process.execPath, [script, fileURLToPath(SHOT_SOURCES)], { cwd: scratch, stdio: 'pipe' });
    assert.deepEqual((await readdir(join(scratch, 'Media'))).sort(), Object.keys(SHOTS).sort(), 'only the two pictures');
    assert.deepEqual((await readdir(scratch)).sort(), ['Media', 'Tools'], 'and nothing beside Media');
    for (const [name, shot] of Object.entries(SHOTS)) {
      const drawn = await readFile(join(scratch, 'Media', name));
      assert.ok(drawn.equals(await readFile(new URL(`../Media/${name}`, import.meta.url))), `${name} as it ships`);
      const png = await readFile(new URL(shot.source, SHOT_SOURCES));
      assert.equal(Math.round(png.readUInt32BE(20) * 512 / png.readUInt32BE(16)), shot.height, `${name}: its shape kept at 512 across`);
    }
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }
});

// Tools/GenerateArt.mjs, run in a scratch folder (its own folder's parent,
// and the folder it runs in): it draws the trail's dot, the cast ring, the
// ring atlas and the five cursor markers exactly as they ship, and nothing
// else. So it never draws over the icons, the heart or the tour's arrow, nor
// the old stand-in arrow (the preview draws the game's own pointer).
test('Tools/GenerateArt.mjs draws only its own art, as it ships', async () => {
  const scratch = await mkdtemp(join(tmpdir(), 'fec-art-'));
  try {
    await mkdir(join(scratch, 'Tools'));
    await mkdir(join(scratch, 'Media'));
    const script = join(scratch, 'Tools', 'GenerateArt.mjs');
    await copyFile(new URL('GenerateArt.mjs', import.meta.url), script);
    execFileSync(process.execPath, [script], { cwd: scratch, stdio: 'pipe' });
    const own = ['CastRing.tga', 'MarkerBullseye.tga', 'MarkerCrosshair.tga', 'MarkerDiamond.tga', 'MarkerDot.tga',
      'MarkerStar.tga', 'Rings.tga', 'TrailDot.tga'];
    assert.deepEqual((await readdir(join(scratch, 'Media'))).sort(), own, 'only its own art');
    assert.deepEqual((await readdir(scratch)).sort(), ['Media', 'Tools'], 'and nothing beside Media');
    assert.deepEqual(await readdir(join(scratch, 'Tools')), ['GenerateArt.mjs'], 'nor beside itself');
    for (const name of own) {
      const drawn = await readFile(join(scratch, 'Media', name));
      assert.ok(drawn.equals(await readFile(new URL(`../Media/${name}`, import.meta.url))), `${name} as it ships`);
    }
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }
});

test('every file in Media is used by the addon, so none ship unused', async () => {
  const files = await readdir(new URL('../', import.meta.url));
  const code = (await Promise.all(files.filter(name => /\.(lua|toc|xml)$/i.test(name)).map(read))).join('\n').toLowerCase();
  const media = await readdir(new URL('../Media/', import.meta.url));
  assert.ok(media.length > 0, 'media to check');
  for (const name of media) {
    assert.ok(code.includes(name.replace(/\.[^.]+$/, '').toLowerCase()), `Media/${name} is used`);
  }
});
