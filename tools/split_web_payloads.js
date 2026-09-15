#!/usr/bin/env node

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const CHUNK_BYTES = 20 * 1024 * 1024;
const PAYLOADS = ['index.pck', 'index.wasm'];

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function fail(message) {
  process.stderr.write(`FAIL ${message}\n`);
  process.exit(1);
}

const outputDir = path.resolve(process.argv[2] || '');
if (!process.argv[2] || !fs.statSync(outputDir, { throwIfNoEntry: false })?.isDirectory()) {
  fail('用法: node tools/split_web_payloads.js <Web 导出目录>');
}

const chunksDir = path.join(outputDir, 'chunks');
if (fs.existsSync(chunksDir) && fs.readdirSync(chunksDir).length > 0) {
  fail(`目标 chunks 目录非空: ${chunksDir}`);
}
fs.mkdirSync(chunksDir, { recursive: true });

const manifest = {
  schema_version: 1,
  chunk_bytes: CHUNK_BYTES,
  generated_at: new Date().toISOString(),
  files: {},
};

for (const fileName of PAYLOADS) {
  const filePath = path.join(outputDir, fileName);
  if (!fs.statSync(filePath, { throwIfNoEntry: false })?.isFile()) {
    fail(`缺少待分片文件: ${fileName}`);
  }
  const source = fs.readFileSync(filePath);
  const parts = [];
  for (let offset = 0, index = 0; offset < source.length; offset += CHUNK_BYTES, index += 1) {
    const part = source.subarray(offset, Math.min(offset + CHUNK_BYTES, source.length));
    const partName = `${fileName}.part${String(index).padStart(2, '0')}`;
    fs.writeFileSync(path.join(chunksDir, partName), part, { flag: 'wx' });
    parts.push({ path: `chunks/${partName}`, bytes: part.length, sha256: sha256(part) });
  }
  manifest.files[fileName] = { bytes: source.length, sha256: sha256(source), parts };
  fs.unlinkSync(filePath);
}

for (const fileName of ['index.html', 'index.js']) {
  const filePath = path.join(outputDir, fileName);
  const source = fs.readFileSync(filePath);
  manifest.files[fileName] = { bytes: source.length, sha256: sha256(source) };
}

fs.writeFileSync(
  path.join(outputDir, 'release-manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
  { flag: 'wx' },
);

process.stdout.write(`PASS Web 大文件已拆成 ${Object.values(manifest.files).flatMap((item) => item.parts || []).length} 个分片\n`);
process.stdout.write(`  输出目录: ${outputDir}\n`);
process.stdout.write(`  清单: ${path.join(outputDir, 'release-manifest.json')}\n`);
