const crypto = require('node:crypto');
const path = require('node:path');
const { test, expect } = require('@playwright/test');

const entryPath = process.env.E2E_ENTRY_PATH || '/';
const fixturePath = path.resolve(__dirname, '../../game/icon.png');

async function launchGarden(page) {
  await page.goto(entryPath, { waitUntil: 'domcontentloaded' });
  const launch = page.getByRole('button', { name: '进入家庭花园' });
  await expect(launch).toBeEnabled();
  await launch.click();
  await expect(page.locator('#audio-launch')).toHaveCount(0);
  await expect(page.locator('#canvas')).toBeFocused();
}

test('手机竖屏提示可在旋转到横屏后恢复游戏画布', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await launchGarden(page);
  await page.waitForTimeout(1500);

  const portraitBounds = await page.locator('#canvas').boundingBox();
  expect(portraitBounds).toMatchObject({ width: 390, height: 844 });
  const portrait = await page.screenshot({
    path: testInfo.outputPath('portrait.png'),
  });
  // 旋转提示是大面积纯色界面，PNG 压缩后本来就很小；只排除空白截图。
  expect(portrait.byteLength).toBeGreaterThan(3_000);

  await page.setViewportSize({ width: 844, height: 390 });
  await page.waitForTimeout(750);

  const landscapeBounds = await page.locator('#canvas').boundingBox();
  expect(landscapeBounds).toMatchObject({ width: 844, height: 390 });
  const landscape = await page.screenshot({
    path: testInfo.outputPath('landscape.png'),
  });
  expect(landscape.byteLength).toBeGreaterThan(3_000);
  expect(crypto.createHash('sha256').update(landscape).digest('hex'))
    .not.toBe(crypto.createHash('sha256').update(portrait).digest('hex'));
});

test('手机浏览器照片输入支持取消并把图片字节交给 Godot', async ({ page }) => {
  await page.setViewportSize({ width: 844, height: 390 });
  await launchGarden(page);

  await expect.poll(() => page.evaluate(() => (
    typeof window.__familyGardenCreatePhotoInput === 'function'
      && typeof window.__familyGardenPhotoPicked === 'function'
  ))).toBe(true);

  await page.evaluate(() => window.__familyGardenCreatePhotoInput());
  const cancelledInput = page.locator('#family-garden-photo-input');
  await expect(cancelledInput).toHaveAttribute('type', 'file');
  await expect(cancelledInput).toHaveAttribute('accept', 'image/png,image/jpeg,image/webp');
  await cancelledInput.dispatchEvent('cancel');
  await expect(cancelledInput).toHaveCount(0);

  await page.evaluate(() => {
    const godotCallback = window.__familyGardenPhotoPicked;
    window.__familyGardenPhotoPicked = (...args) => {
      window.__e2ePhotoPayload = {
        base64Length: String(args[0] || '').length,
        filename: args[1],
        contentType: args[2],
      };
      return Reflect.apply(godotCallback, window, args);
    };
    window.__familyGardenCreatePhotoInput();
  });

  const photoInput = page.locator('#family-garden-photo-input');
  await photoInput.setInputFiles(fixturePath);
  await expect(photoInput).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => window.__e2ePhotoPayload || null))
    .toMatchObject({
      filename: 'icon.png',
      contentType: 'image/png',
    });
  const payload = await page.evaluate(() => window.__e2ePhotoPayload);
  expect(payload.base64Length).toBeGreaterThan(100);
});
