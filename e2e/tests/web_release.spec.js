const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');

const webDir = path.resolve(process.env.E2E_WEB_DIR);
const manifest = JSON.parse(fs.readFileSync(path.join(webDir, 'release-manifest.json'), 'utf8'));
const entryPath = process.env.E2E_ENTRY_PATH || '/';
const expectedIndexCacheControl = process.env.E2E_EXPECT_INDEX_CACHE_CONTROL || 'no-cache';
const expectedChunkCacheControl = process.env.E2E_EXPECT_CHUNK_CACHE_CONTROL || 'immutable';

test('干净浏览器可完成加载、音频解锁与真实 Canvas 渲染', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });

  const indexResponse = await page.goto(entryPath, { waitUntil: 'domcontentloaded' });
  expect(indexResponse.status()).toBe(200);
  expect(indexResponse.headers()['cache-control']).toContain(expectedIndexCacheControl);

  const firstPckPart = manifest.files['index.pck'].parts[0].path;
  const chunkResponse = await page.request.get(firstPckPart);
  expect(chunkResponse.status()).toBe(200);
  expect(chunkResponse.headers()['cache-control']).toContain(expectedChunkCacheControl);

  const launch = page.getByRole('button', { name: '进入家庭花园' });
  await expect(launch).toBeEnabled();
  await launch.click();
  await expect(page.locator('#audio-launch')).toHaveCount(0);
  await expect(page.locator('#canvas')).toBeFocused();

  await page.waitForTimeout(1500);
  const screenshot = await page.locator('#canvas').screenshot();
  // 纯色 1280×720 PNG 远低于此值；验证 Canvas 不是空白，同时不绑定具体美术压缩率。
  expect(screenshot.byteLength).toBeGreaterThan(10_000);
  expect(errors).toEqual([]);
});

test('分片缺失时给用户稳定、可见且不可误进入的失败状态', async ({ page }) => {
  await page.route('**/chunks/index.pck.part00', async (route) => {
    await route.fulfill({ status: 503, contentType: 'text/plain', body: 'simulated outage' });
  });
  await page.goto(entryPath, { waitUntil: 'domcontentloaded' });

  await expect(page.locator('#audio-launch-message')).toHaveText('加载失败，请刷新页面后重试。');
  await expect(page.getByRole('button', { name: '暂时无法进入' })).toBeDisabled();
  await expect(page.locator('#status-notice')).toContainText('index.pck.part00');
});
