// The addon's rules, checked straight from its source: Blizzard's frames are
// never written on, shown, hidden, moved, scaled or resized; the game's own
// settings are never changed; no text is ever run as code; the parts run every
// frame make nothing (no tables, functions or text); EraUI's saved settings
// are only read, and only while EraUI is loaded; the game's colour picker is
// never used (the addon has its own); the effects never take the mouse; the Auto-switch rules only show a profile,
// never per frame, and read a mount's aura only out of a fight; the TOC,
// licence and art are right; the highlight while looking is the game's own
// pointer, its fingertip on the spot; no em dash, even as an escape; no function
// given twice in a file; and no other addon is named anywhere.
// Run with: node Tools/TestRules.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
const read = name => readFile(new URL(name, root), 'utf8');

async function rootFiles(pattern) {
  return (await readdir(root, { withFileTypes: true }))
    .filter(entry => entry.isFile() && pattern.test(entry.name)).map(entry => entry.name).sort();
}

// The addon's code with its comments and strings blanked out (lines kept),
// so only code is checked.
function codeOnly(lua) {
  let out = '';
  let i = 0;
  const blank = text => text.replace(/[^\n]/g, ' ');
  while (i < lua.length) {
    const rest = lua.slice(i);
    let match;
    if ((match = rest.match(/^--\[(=*)\[[\s\S]*?\]\1\]/))) {
      out += blank(match[0]);
    } else if ((match = rest.match(/^--[^\n]*/))) {
      out += blank(match[0]);
    } else if ((match = rest.match(/^\[(=*)\[[\s\S]*?\]\1\]/))) {
      out += '""' + blank(match[0].slice(2));
    } else if ((match = rest.match(/^"(?:[^"\\\n]|\\.)*"/)) || (match = rest.match(/^'(?:[^'\\\n]|\\.)*'/))) {
      out += '""' + blank(match[0].slice(2));
    } else {
      match = [lua[i]];
      out += lua[i];
    }
    i += match[0].length;
  }
  return out;
}

// The text in a Lua file's strings, one entry each (comments left out).
function literals(lua) {
  const found = [];
  let i = 0;
  while (i < lua.length) {
    const rest = lua.slice(i);
    let match;
    if ((match = rest.match(/^--\[(=*)\[[\s\S]*?\]\1\]/)) || (match = rest.match(/^--[^\n]*/))) {
      // a comment
    } else if ((match = rest.match(/^\[(=*)\[([\s\S]*?)\]\1\]/))) {
      found.push({ text: match[2], index: i });
    } else if ((match = rest.match(/^"((?:[^"\\\n]|\\.)*)"/)) || (match = rest.match(/^'((?:[^'\\\n]|\\.)*)'/))) {
      found.push({ text: match[1], index: i });
    } else {
      match = [lua[i]];
    }
    i += match[0].length;
  }
  return found;
}

async function addonCode() {
  const files = await rootFiles(/\.lua$/i);
  assert.ok(files.length >= 10, 'the addon files found');
  return Promise.all(files.map(async name => ({ name, source: await read(name), code: codeOnly(await read(name)) })));
}

function lineOf(text, index) {
  return text.slice(0, index).split('\n').length;
}

// Blizzard's frames the addon could reach by name.
const BLIZZARD = String.raw`(?:UIParent|WorldFrame|Minimap|MinimapCluster|GameTooltip|ColorPickerFrame|OpacityFrame|PlayerFrame|`
  + String.raw`TargetFrame|MainMenuBar|SettingsPanel|DEFAULT_CHAT_FRAME|ChatFrame\d+)`;
// A field chain after the name: .Content, ["name"], .Content.HexBox
const CHAIN = String.raw`((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))*)`;
// What would show, hide, move, scale, resize, re-parent or take over one.
const FORBIDDEN = new Set(['Show', 'Hide', 'SetShown', 'SetScale', 'SetSize', 'SetWidth', 'SetHeight', 'SetPoint',
  'ClearAllPoints', 'ClearPoint', 'SetAllPoints', 'SetParent', 'SetScript', 'SetFrameStrata', 'SetFrameLevel',
  'EnableMouse', 'SetAttribute', 'RegisterEvent', 'RegisterUnitEvent', 'UnregisterEvent', 'UnregisterAllEvents',
  'SetMovable', 'StartMoving', 'StopMovingOrSizing', 'SetClampedToScreen', 'SetUserPlaced', 'SetIgnoreParentScale',
  'SetIgnoreParentAlpha', 'SetToplevel', 'Raise', 'Lower', 'SetID', 'Enable', 'Disable', 'SetAlpha', 'SetColorRGB']);

test('no show, hide, move, scale, resize or script on a Blizzard frame named in the code', async () => {
  const found = [];
  const call = new RegExp(String.raw`(?<![\w.:])(${BLIZZARD})${CHAIN}\s*:\s*([A-Za-z_]\w*)\s*\(`, 'g');
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(call)) {
      if (FORBIDDEN.has(match[3])) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}${match[2]}:${match[3]}`);
    }
  }
  assert.deepEqual(found, []);
});

test('no key written on a Blizzard frame named in the code', async () => {
  const found = [];
  const write = new RegExp(String.raw`(?<![\w.:])(${BLIZZARD})((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))+)\s*=(?!=)`, 'g');
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(write)) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}${match[2]} =`);
  }
  assert.deepEqual(found, []);
});

test('nothing gets round the rules: no rawset, and no game setting changed', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/(?<![\w.:])(rawset|SetCVar|SetCVarBitfield|ShowUIPanel|HideUIPanel|securecall|issecurevariable|ReloadUI|ConsoleExec)\s*\(/g)) {
      found.push(`${name}:${lineOf(code, match.index)} ${match[1]}`);
    }
    for (const match of code.matchAll(/\.\s*(SetCVar|SetCVarBitfield)\s*\(/g)) {
      found.push(`${name}:${lineOf(code, match.index)} ${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
});

// Nothing in the addon turns text into code: none of Lua's or the game's
// ways to run text is named in the code (called, passed to pcall, kept in a
// local or reached through _G), nor written as text that could look one up.
// The game's encoder is for shared profiles only (ProfileTools.lua).
const RUN = ['loadstring', 'load', 'loadfile', 'dofile', 'RunScript', 'RunMacroText', 'RunMacro', 'setfenv', 'getfenv',
  'getglobal'];
test('no text is ever run as code', async () => {
  const found = [];
  const named = new RegExp(String.raw`(?<![\w])(${RUN.join('|')})(?![\w])`, 'g');
  for (const { name, source, code } of await addonCode()) {
    for (const match of code.matchAll(named)) found.push(`${name}:${lineOf(source, match.index)} ${match[1]}`);
    for (const match of code.matchAll(/JSON/g)) found.push(`${name}:${lineOf(source, match.index)} JSON`);
    for (const { text, index } of literals(source)) {
      const piece = RUN.find(word => text === word || (text.length >= 4 && word.startsWith(text)));
      if (piece) found.push(`${name}:${lineOf(source, index)} "${text}" (${piece} by name)`);
    }
    if (name !== 'ProfileTools.lua') {
      for (const match of code.matchAll(/C_EncodingUtil/g)) found.push(`${name}:${lineOf(source, match.index)} C_EncodingUtil`);
    }
  }
  assert.deepEqual(found, [], 'nothing names a way to run text');
});

// The parts run every frame sit between "-- per frame: start" and
// "-- per frame: end" marks, and make nothing: no table ({), function,
// joined text (..), format, tostring, pairs or ipairs, and no frame or texture.
// The frame's own OnUpdate scripts are among them.
test('the parts run every frame make nothing', async () => {
  const found = [];
  const regions = {};
  for (const { name, source, code } of await addonCode()) {
    const starts = [...source.matchAll(/-- per frame: start/g)].map(match => match.index);
    const ends = [...source.matchAll(/-- per frame: end/g)].map(match => match.index);
    assert.equal(starts.length, ends.length, `${name}: every per-frame start has an end`);
    regions[name] = starts.length;
    starts.forEach((start, i) => {
      assert.ok(ends[i] > start && (starts[i + 1] === undefined || ends[i] < starts[i + 1]), `${name}: marks in pairs`);
      const body = code.slice(start, ends[i]);
      for (const match of body.matchAll(/\{|\bfunction\b|\.\.|\bformat\b|\btostring\b|\bpairs\b|\bipairs\b|\bCreateTexture\b|\bCreateFrame\b|\bsetmetatable\b|\bselect\b/g)) {
        found.push(`${name}:${lineOf(source, start + match.index)} ${match[0]}`);
      }
    });
  }
  assert.deepEqual(found, [], 'nothing made in a frame');
  assert.deepEqual({ trail: regions['Trail.lua'], engine: regions['Engine.lua'], cast: regions['Cast.lua'], preview: regions['Preview.lua'],
    style: regions['Style.lua'] }, { trail: 5, engine: 1, cast: 2, preview: 1, style: 1 },
    'the trail\'s Put, Walk, Move, HeadColour and Tick, the engine\'s and preview\'s frame, the cast ring\'s Tint and Tick, the highlight\'s TintLook');
  // Each OnUpdate script of the effects' is one of those.
  for (const [file, fn] of [['Engine.lua', 'Update'], ['Preview.lua', 'Update']]) {
    const source = await read(file);
    assert.match(source, new RegExp(String.raw`SetScript\("OnUpdate", ${fn}\)`), `${file} runs ${fn} each frame`);
    assert.match(source, new RegExp(String.raw`local function ${fn}\([^)]*\)\r?\n\s*-- per frame: start`), `${file}: ${fn} is marked`);
  }
});

// EraUI's saved settings are only read, in FromEraUI.lua alone, and EraUI
// itself is never called.
test("EraUI's saved settings are only read, in one file", async () => {
  const found = [];
  for (const { name, code, source } of await addonCode()) {
    for (const match of source.matchAll(/EraUIDB/g)) {
      const inCode = code.slice(match.index, match.index + 7) === 'EraUIDB';
      if (inCode && name !== 'FromEraUI.lua') found.push(`${name}:${lineOf(source, match.index)} EraUIDB`);
    }
    for (const match of code.matchAll(/(?<![\w.:])EraUI\b/g)) found.push(`${name}:${lineOf(code, match.index)} EraUI`);
  }
  assert.deepEqual(found, [], 'only FromEraUI.lua names EraUI\'s settings, and nothing calls EraUI');
  const era = codeOnly(await read('FromEraUI.lua'));
  assert.match(era, /local check = C_AddOns and C_AddOns\.IsAddOnLoaded or IsAddOnLoaded\r?\n/, 'it asks the game whether EraUI is loaded');
  assert.match(era, /local function Saved\(\)\r?\n\s*if not F\.Loaded\(\) then return nil end/, 'and reads nothing of EraUI\'s without it');
  assert.equal([...era.matchAll(/EraUIDB/g)].length, 1, 'reached once');
  assert.match(era, /local saved = _G\.EraUIDB\r?\n/, 'into a local');
  assert.doesNotMatch(era, /EraUIDB\s*=(?!=)|\bsaved\s*(\.\s*\w+|\[[^\]]*\])\s*=(?!=)/, 'never written');
});

// The game's colour picker is never used, not even read: the addon has its
// own (ColourPicker.lua), built from plain frames of its own in its own look.
test("the game's colour picker is never used", async () => {
  const found = [];
  const names = /ColorPicker|OpacityFrame|OpacitySliderFrame|OpenColorPicker/;
  for (const { name, source, code } of await addonCode()) {
    for (const match of code.matchAll(new RegExp(names, 'g'))) found.push(`${name}:${lineOf(code, match.index)} ${match[0]}`);
    for (const { text, index } of literals(source)) {
      if (names.test(text)) found.push(`${name}:${lineOf(source, index)} "${text}"`);
    }
  }
  assert.deepEqual(found, [], "nothing names the game's colour picker");
  const own = await read('ColourPicker.lua');
  const made = [...own.matchAll(/CreateFrame\("(\w+)", nil, \w+(?:, "(\w+)")?\)/g)];
  assert.ok(made.length >= 5, 'the picker makes its own frames');
  for (const match of made) {
    assert.ok(match[2] === undefined || match[2] === 'BackdropTemplate', `no template of the game's but the plain backdrop (${match[0]})`);
  }
  assert.match(await read('Window.lua'), /ns\.ColourPicker:Build\(window\)/, 'the window builds it');
  assert.match(await read('Core.lua'), /ns\.ColourPicker:Cancel\(\)/, 'Escape cancels it');
});

// The effects never take the mouse: no clicks, hovers or wheel on them.
test('the effects never take the mouse', async () => {
  for (const name of ['Engine.lua', 'Cast.lua', 'Style.lua', 'Trail.lua']) {
    const code = codeOnly(await read(name));
    assert.doesNotMatch(code, /EnableMouse\(\s*true|EnableMouseWheel|SetPropagate|RegisterForClicks/, `${name}: never mouse-enabled`);
    assert.doesNotMatch(await read(name), /"On(Enter|Leave|MouseDown|MouseUp|Click|MouseWheel)"/, `${name}: no mouse scripts`);
  }
  const engine = await read('Engine.lua');
  assert.match(engine, /driver:EnableMouse\(false\)/, 'the effects\' frame says so');
  assert.match(engine, /driver:SetFrameStrata\("TOOLTIP"\)/, 'above the game\'s windows');
});

// The Auto-switch rules only show a profile for a while (Core.lua's
// override): they never pick one, make, rename, delete or change one, or
// change a setting. They look only on events, never each frame, and a
// mount's aura (which may be secret in a fight) only out of one.
test('the Auto-switch rules only show a profile, on events only', async () => {
  const code = codeOnly(await read('AutoSwitch.lua'));
  const changers = /\bns\s*\.\s*(UseProfile|NewProfile|NewProfileFrom|CopyProfile|RenameProfile|DeleteProfile|SetAccountWide|ReplaceSettings|Set|SetRulePick|SetMountPick|AddMount|RemoveMount|SetTalentPick)\s*\(/g;
  assert.deepEqual([...code.matchAll(changers)].map(match => match[1]), [], 'no pick, profile or setting changed');
  assert.match(code, /ns\.SetOverride\(name\)/, 'only the profile shown');
  assert.doesNotMatch(code, /OnUpdate/, 'never each frame');
  for (const { name, code: other } of await addonCode()) {
    if (name !== 'AutoSwitch.lua' && name !== 'Core.lua') {
      assert.doesNotMatch(other, /GetPlayerAuraBySpellID|C_MountJournal|SetOverride\s*\(/, name + ": mounts and the override are AutoSwitch.lua's");
    }
  }
  const source = await read('AutoSwitch.lua');
  const find = source.slice(source.indexOf('local function FindMount()'), source.indexOf('local function ReadMount()'));
  const guard = find.indexOf('if State.combat then return nil end');
  assert.ok(guard > 0 && guard < find.indexOf('GetPlayerAuraBySpellID'), 'auras only out of a fight');
});

// Frames named in the game's global space are the addon's own.
test('every frame name is the addon\'s own', async () => {
  const found = [];
  for (const { name, source } of await addonCode()) {
    for (const match of source.matchAll(/CreateFrame\(\s*"\w+"\s*,\s*"([^"]+)"/g)) {
      if (!match[1].startsWith('FECursor')) found.push(`${name}:${lineOf(source, match.index)} ${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
});

// A function defined on a name the file doesn't own (a local, or a function's
// argument) would replace one of the game's instead of hooking it.
test('the game\'s functions are never replaced', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    const own = new Set();
    for (const match of code.matchAll(/\blocal\s+function\s+([A-Za-z_]\w*)/g)) own.add(match[1]);
    for (const match of code.matchAll(/\blocal\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)/g)) {
      for (const part of match[1].split(',')) own.add(part.trim());
    }
    for (const match of code.matchAll(/\bfunction\s*[\w.:]*\s*\(([^)]*)\)/g)) {
      for (const part of match[1].split(',')) own.add(part.trim());
    }
    for (const match of code.matchAll(/\bfunction\s+([A-Za-z_]\w*)((?:\s*[.:]\s*\w+)*)\s*\(/g)) {
      if (!own.has(match[1])) found.push(`${name}:${lineOf(code, match.index)} function ${match[1]}${match[2]}`);
    }
  }
  assert.deepEqual(found, [], "global functions are the game's; the addon keeps its own on ns or in locals");
});

test('the TOC loads every file, for Forever, by Squirt', async () => {
  const toc = await read('ForeverEnhancedCursor.toc');
  assert.match(toc, /^## Interface: 16001$/m);
  assert.match(toc, /^## Title: Forever Enhanced Cursor$/m);
  assert.match(toc, /^## Author: Squirt$/m);
  // Uploaded to CurseForge by hand, with no packager to fill a placeholder
  // in: the TOC carries the newest released version's number itself.
  const version = toc.match(/^## Version: (\d+\.\d+\.\d+)$/m)?.[1];
  assert.ok(version, 'a version number of its own in the TOC');
  const released = (await read('CHANGELOG.txt')).match(/^## (\d+\.\d+\.\d+)$/m)?.[1];
  assert.equal(version, released, 'the newest version CHANGELOG.txt has notes for');
  assert.match(toc, /^## SavedVariables: ForeverEnhancedCursorDB$/m);
  assert.doesNotMatch(toc, /SavedVariablesPerCharacter/, 'account-wide settings only');
  assert.match(toc, /^## IconTexture: Interface\\AddOns\\ForeverEnhancedCursor\\Media\\FECIcon\.tga$/m);
  assert.match(toc, /^## OptionalDeps: EraUI$/m, 'EraUI first, when there, so its settings can be read');
  const listed = toc.split(/\r?\n/).filter(line => line && !line.startsWith('#'));
  assert.deepEqual([...listed].sort(), await rootFiles(/\.lua$/i), 'every file listed, and each one there');
  assert.equal(listed[0], 'Core.lua', 'the settings load first');
  const harness = (await read('Tools/Harness.lua')).match(/^H\.FILES = \{([^}]*)\}/m);
  assert.ok(harness, 'H.FILES found in Tools/Harness.lua');
  assert.deepEqual([...harness[1].matchAll(/"([^"]+)"/g)].map(match => match[1]), listed, 'the tests load what the game loads');
});

test('All Rights Reserved, and packaged without the tools', async () => {
  const licence = await read('LICENSE.txt');
  assert.match(licence, /^Copyright \(c\) 2026 Squirt\. All rights reserved\.$/m);
  assert.match(licence, /Forever Enhanced Cursor and its source code are the property of the\s+author/);
  const pkgmeta = await read('.pkgmeta');
  assert.match(pkgmeta, /^package-as: ForeverEnhancedCursor$/m);
  assert.match(pkgmeta, /^manual-changelog: CHANGELOG\.txt$/m);
  assert.match(await read('CHANGELOG.txt'), /^# Changelog\r?\n/, 'the changelog it names is there');
  for (const folder of ['.github', 'Screenshots', 'Tools']) assert.match(pkgmeta, new RegExp(`^  - ${folder}$`, 'm'));
  const ignore = await read('.gitignore');
  assert.match(ignore, /^Tools\/ReleasePreview\.md$/m, 'the private notes stay private');
  assert.match(ignore, /^Tools\/ReleaseAudit-\*\.md$/m);
});

// The art: every file used, each an uncompressed 32-bit TGA, square and a
// power of two across. Which way its rows run (bottom first for the icons,
// the heart, the tour's arrow and the cooldown manager's pictures, top first
// for Tools/GenerateArt.mjs's) is TestNotes.mjs's to check.
test('the art: every file used, and each one the game can load', async () => {
  const media = (await readdir(new URL('Media/', root))).sort();
  const sources = (await Promise.all((await rootFiles(/\.(lua|toc)$/i)).map(read))).join('\n');
  for (const file of media) {
    assert.ok(sources.includes(file), `${file} is used`);
    const data = await readFile(new URL(`Media/${file}`, root));
    const width = data.readUInt16LE(12), height = data.readUInt16LE(14);
    assert.equal(data[2], 2, `${file}: uncompressed`);
    assert.equal(data[16], 32, `${file}: 32-bit`);
    assert.equal(width, height, `${file}: square`);
    assert.equal(width & (width - 1), 0, `${file}: a power of two`);
    assert.equal(data.length, 18 + width * height * 4, `${file}: whole`);
  }
  for (const file of ['FECIcon.tga', 'MinimapIcon.tga', 'TrailDot.tga', 'CastRing.tga', 'Rings.tga', 'Heart.tga', 'TourArrow.tga']) {
    assert.ok(media.includes(file), `${file} there`);
  }
  // The preview draws the game's own pointer, the gauntlet: no stand-in.
  assert.ok(!media.includes('PreviewArrow.tga'), 'no stand-in arrow');
  assert.match(await read('Style.lua'), /^S\.POINTER = "Interface\\\\Cursor\\\\Point"\r?\n/m, "the game's pointer, named once in Style.lua");
  assert.match(codeOnly(await read('Preview.lua')), /\n\s*pointer:SetTexture\(Style\.POINTER\)\r?\n/, 'the preview draws it');
  const rings = await readFile(new URL('Media/Rings.tga', root));
  assert.equal(rings.readUInt16LE(12), 1024, 'the ring atlas: 8 by 8 cells of 128');
});

// The highlight while looking is a see-through copy of the game's pointer,
// its fingertip (the top left corner) on the spot, as the preview's pointer
// is: no ring and no dot, and placed only through Style.PlaceLook, on screen
// and in the preview alike.
test('the highlight while looking is the game\'s pointer, its fingertip on the spot', async () => {
  const style = await read('Style.lua');
  const body = fn => {
    const match = style.match(new RegExp(String.raw`\nfunction S\.${fn}\(([^)]*)\)\r?\n([\s\S]*?)\nend\r?\n`));
    assert.ok(match, `Style.lua has S.${fn}`);
    return match[2];
  };
  const look = codeOnly(['NewLook', 'PlaceLook', 'PaintLook', 'TintLook', 'LookColour'].map(body).join('\n'));
  assert.match(codeOnly(body('NewLook')), /\n\s*texture:SetTexture\(S\.POINTER\)\r?\n/, 'the game\'s own pointer');
  assert.doesNotMatch(look, /RINGS|DOT|NewRing|PaintRing|RingCell|\.dot\b|CreateTexture[\s\S]*CreateTexture/,
    'one texture, the pointer: no ring and no dot');
  assert.match(body('PlaceLook'), /^\s*frame:SetPoint\("TOPLEFT", relative, relativePoint, x, y\)\s*$/, 'its fingertip on the spot');
  assert.match(await read('Preview.lua'), /\n\s*pointer:SetPoint\("TOPLEFT", strip, "BOTTOMLEFT", px, py\)\r?\n/,
    'as the preview\'s pointer is');
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/\blook\s*:\s*(SetPoint|SetAllPoints|ClearAllPoints)\b/g)) found.push(`${name}:${lineOf(code, match.index)}`);
    if (name !== 'Style.lua') {
      for (const { text, index } of literals(await read(name))) {
        if (/Interface\\\\Cursor/i.test(text)) found.push(`${name}:${lineOf(code, index)} names a cursor file`);
      }
    }
  }
  assert.deepEqual(found, [], 'placed only through Style.PlaceLook, and the pointer named only in Style.lua');
  assert.match(await read('Engine.lua'), /\n\s*Style\.PlaceLook\(look, anchor, "CENTER", 0, 0\)\r?\n/, 'on screen: on the anchor');
  assert.match(await read('Preview.lua'), /\n\s*Style\.PlaceLook\(look, strip, "BOTTOMLEFT", px, py\)\r?\n/,
    'in the preview: where the pointer\'s fingertip was');
});

test('no em dashes in anything players read', async () => {
  for (const name of await rootFiles(/\.(lua|toc|md|txt)$/i)) {
    assert.doesNotMatch(await read(name), /—/, name);
  }
  // Nor one written as an escape in the code's strings (its bytes 226 128 148,
  // in decimal or hex, or its code point).
  const escaped = /\\226\\128\\148|\\x[eE]2\\x80\\x94|\\u\{0*2014\}/;
  const found = [];
  for (const { name, source } of await addonCode()) {
    for (const { text, index } of literals(source)) if (escaped.test(text)) found.push(`${name}:${lineOf(source, index)}`);
  }
  assert.deepEqual(found, [], 'no em dash written as an escape');
});

// A function given a second time in one file replaces the first unseen, so
// each is given once.
test('no function is defined twice in one file', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    const seen = new Set();
    for (const match of code.matchAll(/\bfunction\s+([A-Za-z_]\w*\s*[.:]\s*[A-Za-z_][\w.:]*)\s*\(/g)) {
      const fn = match[1].replace(/\s+/g, '');
      if (seen.has(fn)) found.push(`${name}:${lineOf(code, match.index)} ${fn}`);
      seen.add(fn);
    }
  }
  assert.deepEqual(found, []);
});

// Other addons are never named, in the addon, its text or its tests. Their
// names are kept here as hashes only, so this file names none either. EraUI
// is Squirt's own: its effects are noticed (read only), so the code names it.
// So are the Forever Enhanced addons the General page's More from Squirt
// lists (2026-10-03, the user's ask): their own names (OWN) are passed over
// whole, so a word or two of one that another addon's name shares counts
// as theirs. Nothing else of the list is let through.
const OTHERS = new Set(['06826c441678339a', 'fdd508e96907f59b', '7f466e6770936442',
  '9c30a3e707dcf583', '72ecb0128ced47c2', '6fc79fada620a1c9', 'e52a90bc5daa975e', 'af6d017462ed41ba', '0bbe8420d9c30286',
  '5cab34c79b0b9875', '007e4d0cfa14fe5f', '4f23dd1f73797e72', '88ed36849a168ebc', '95926befd4f439b3', '9f576eec3619bfe2',
  '17e96a475e1830bf', 'f12a22af8df5e508', '3494444fd5c12c8c', '16614b5df8db4ed3', '89c5df462dcb969f', '8e1fd1320c1ec0c9',
  '7b841cc1685b8265', '6ab18144a65cb982', '94d9217d231a426a', '0cdaf053d971025e', 'f2b83e490eacf0ab', 'f570e5c3bf419861',
  '7641fefdddae81a8', 'f30b3dec56800f2d', 'b36304575a067c83', '36b8e826fe73ecd1', '9f7ffe1ac0b90e2d', 'f6642857381c08dc',
  'fb8e46d54110a9ff', '1b9c0bcd7113eacd', '2e21a65ec2ad8687', 'd69e0ac49ca8e11d', 'dafeaf414c71197e', 'f0354e832758ef47',
  'c92ae2f85364c65b', '02aca0a6f01611ce', '1c835ab4bac854a0', 'e04637df5b0cfa3e', '47e63f8db8f80cf8']);
const hash = text => createHash('sha1').update(text).digest('hex').slice(0, 16);
const OWN = ['forever enhanced cooldown manager', 'forever enhanced raid frames', 'fecm'].map(name => name.split(' '));

// Which words are part of one of Squirt's own addons' names.
function ownWords(words) {
  const own = new Set();
  for (let i = 0; i < words.length; i++) {
    for (const name of OWN) {
      if (name.every((word, j) => words[i + j] === word)) name.forEach((_, j) => own.add(i + j));
    }
  }
  return own;
}

test('no other addon is named anywhere', async () => {
  const names = [...await rootFiles(/\.(lua|toc|md|txt|html)$|^\.pkgmeta$|^\.gitignore$/i)];
  const tools = await readdir(new URL('Tools/', root));
  for (const name of tools) {
    if (/\.(lua|mjs|js|html)$/i.test(name)) names.push(`Tools/${name}`);
  }
  assert.ok(names.includes('Tools/TestRules.mjs') && names.includes('Core.lua'), 'the files to check');
  const found = [];
  for (const name of names) {
    const words = (await read(name)).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
    const own = ownWords(words);
    for (let i = 0; i < words.length; i++) {
      for (let n = 1; n <= 4 && i + n <= words.length; n++) {
        if (words.slice(i, i + n).some((_, j) => own.has(i + j))) continue;
        if (OTHERS.has(hash(words.slice(i, i + n).join(' ')))) found.push(`${name}: word ${i + 1}`);
      }
    }
  }
  assert.deepEqual(found, []);
  // Only Squirt's own names, whole, are passed over: the words they share
  // with the list still count anywhere else.
  const shared = OWN[0].slice(1); // its name but its first word
  assert.ok(OTHERS.has(hash(shared.join(' '))), "a name the list has, shared in part with one of Squirt's");
  assert.equal(ownWords(shared).size, 0, 'counted on its own');
  assert.equal(ownWords(['forever', ...shared]).size, 4, 'and passed over only as part of the whole own name');
});
