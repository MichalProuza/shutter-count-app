#!/usr/bin/env node
// Validation script — extracts parser functions from index.html and runs them against Samples/
import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';

// ── Extract and eval the parser code from index.html ──
const html = readFileSync(join(import.meta.dirname, 'index.html'), 'utf-8');
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
if (!scriptMatch) { console.error('No <script> found'); process.exit(1); }

// Extract only the parser functions (before UI code starting with "const allResults")
const fullScript = scriptMatch[1];
const uiStart = fullScript.indexOf('// ── Results tracking');
const parserCode = uiStart > 0 ? fullScript.slice(0, uiStart) : fullScript;

// Eval parsers into this scope
const fn = new Function(parserCode + '\nreturn {parseCR3,parseExif,parseRAF,parseFile,parseIFD,iStr,r16,r32,r64,s4};');
const P = fn();

// ── Run against sample files ──
const sampleDirCandidates = ['Raws_small_truncated', 'Samples'];
const samplesDir = sampleDirCandidates
  .map(dir => join(import.meta.dirname, dir))
  .find(dir => {
    try { readdirSync(dir); return true; } catch { return false; }
  });
if (!samplesDir) {
  console.error(`No sample directory found. Tried: ${sampleDirCandidates.join(', ')}`);
  process.exit(1);
}
const files = readdirSync(samplesDir);

const PASS = '\x1b[32m✓\x1b[0m';
const FAIL = '\x1b[31m✗\x1b[0m';
const WARN = '\x1b[33m⚠\x1b[0m';
let passed = 0, warned = 0, failed = 0;

for (const file of files) {
  const ext = file.slice(file.lastIndexOf('.')).toLowerCase();
  if (!['.cr2','.cr3','.nef','.arw','.raf','.orf','.rw2','.dng','.jpg','.jpeg'].includes(ext)) continue;

  const buf = readFileSync(join(samplesDir, file));
  const ab = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);

  let result, error;
  try {
    result = P.parseFile(ab);
  } catch (e) {
    error = e;
  }

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`Soubor: ${file} (${(buf.length / 1048576).toFixed(1)} MB)`);
  console.log(`${'─'.repeat(60)}`);

  if (error) {
    console.log(`  ${FAIL} PARSER CRASH: ${error.message}`);
    console.log(`     ${error.stack?.split('\n').slice(1,3).join('\n     ')}`);
    failed++;
    continue;
  }

  if (!result) {
    console.log(`  ${FAIL} Parser vrátil null/undefined`);
    failed++;
    continue;
  }

  // Validate fields
  const r = result;

  // Make
  if (r.make) {
    console.log(`  ${PASS} Make: ${r.make}`);
  } else {
    console.log(`  ${FAIL} Make: nenalezeno`);
    failed++;
  }

  // Model
  if (r.model) {
    console.log(`  ${PASS} Model: ${r.model}`);
  } else {
    console.log(`  ${WARN} Model: nenalezeno`);
    warned++;
  }

  // ShutterCount
  if (r.shutterCount != null && r.shutterCount > 0) {
    console.log(`  ${PASS} ShutterCount: ${r.shutterCount.toLocaleString('cs-CZ')} (${r.method})`);
    passed++;
  } else {
    // Check expected behavior
    const model = (r.model || '').toUpperCase();
    const is5D = model.includes('5D');
    const isR1 = model.includes('R1');
    if (is5D && ext === '.cr2') {
      console.log(`  ${PASS} ShutterCount: nenalezeno (OČEKÁVÁNO — Canon 5D nezapisuje SC do EXIF)`);
      passed++;
    } else if (isR1 && ext === '.cr3') {
      console.log(`  ${WARN} ShutterCount: nenalezeno (offset pro R1 není znám — probe mode)`);
      warned++;
    } else {
      console.log(`  ${WARN} ShutterCount: nenalezeno`);
      warned++;
    }
  }

  // Probe values for unknown CR3 bodies
  if (r._probeValues) {
    const lines = r._probeValues.split('\n');
    console.log(`  ${PASS} Probe dump nalezen (${lines.length} skupin):`);
    for (const line of lines) {
      const truncated = line.length > 120 ? line.slice(0, 117) + '...' : line;
      console.log(`       ${truncated}`);
    }
  }

  if (r._cr3BlockSize) {
    console.log(`  ${PASS} CR3 blok 0x000D: ${r._cr3BlockSize} B (0x${r._cr3BlockSize.toString(16).toUpperCase()})`);
  }

  // FileNumber (for consumer Canon CR2)
  if (r.fileNumber) {
    console.log(`  ${PASS} FileNumber: ${r.fileNumber} (dir=${r.dirIndex}, file=${r.fileIndex})`);
  }

  // DateTime
  if (r.dateTime) console.log(`  ${PASS} DateTime: ${r.dateTime}`);
  else console.log(`  ${WARN} DateTime: nenalezeno`);

  // Firmware
  if (r.firmware) console.log(`  ${PASS} Firmware: ${r.firmware}`);

  // EXIF metadata
  if (r.iso) console.log(`  ${PASS} ISO: ${r.iso}`);
  if (r.focalLength) console.log(`  ${PASS} FocalLength: ${r.focalLength}`);
  if (r.aperture) console.log(`  ${PASS} Aperture: ${r.aperture}`);
  if (r.shutterSpeed) console.log(`  ${PASS} ShutterSpeed: ${r.shutterSpeed}`);
  if (r.lensModel) console.log(`  ${PASS} Lens: ${r.lensModel}`);
}

console.log(`\n${'═'.repeat(60)}`);
console.log(`VÝSLEDKY: ${passed} ok, ${warned} varování, ${failed} chyb`);
console.log(`${'═'.repeat(60)}`);
process.exit(failed > 0 ? 1 : 0);
