#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const dist = path.join(root, 'dist');
const files = ['index.js', 'package.json', 'package-lock.json'];

fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });
for (const file of files) fs.copyFileSync(path.join(root, file), path.join(dist, file));

const forbidden = ['.env', '.git', 'node_modules', 'tests', 'data_gateway.zip'];
const entries = fs.readdirSync(dist, { recursive: true });
for (const token of forbidden) {
  if (entries.some((entry) => String(entry).split(path.sep).includes(token))) {
    throw new Error(`部署包包含禁止路径: ${token}`);
  }
}

process.stdout.write(`Data Gateway 部署包已生成: ${dist}（${files.length} 个文件）\n`);
