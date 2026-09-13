#!/usr/bin/env node

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const root = path.resolve(process.env.E2E_WEB_DIR || '');
if (!process.env.E2E_WEB_DIR || !fs.statSync(root, { throwIfNoEntry: false })?.isDirectory()) {
  throw new Error('E2E_WEB_DIR 必须是可部署 Web Release 目录');
}

const mime = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.wasm', 'application/wasm'],
]);

http.createServer((request, response) => {
  const urlPath = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
  const relative = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const target = path.resolve(root, relative);
  if (target !== root && !target.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403).end('Forbidden');
    return;
  }
  const stat = fs.statSync(target, { throwIfNoEntry: false });
  if (!stat?.isFile()) {
    response.writeHead(404).end('Not found');
    return;
  }
  const isVersionedPayload = relative.startsWith('chunks/');
  response.writeHead(200, {
    'Content-Type': mime.get(path.extname(target)) || 'application/octet-stream',
    'Content-Length': stat.size,
    'Cache-Control': isVersionedPayload ? 'public, max-age=31536000, immutable' : 'no-cache',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  if (request.method === 'HEAD') {
    response.end();
    return;
  }
  fs.createReadStream(target).pipe(response);
}).listen(4173, '127.0.0.1', () => {
  process.stdout.write(`Family Garden E2E server: ${root}\n`);
});
