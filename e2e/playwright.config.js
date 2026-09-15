const { defineConfig } = require('@playwright/test');

const webDir = process.env.E2E_WEB_DIR;
if (!webDir) throw new Error('缺少 E2E_WEB_DIR（应指向 build_web_release.sh 的输出目录）');

module.exports = defineConfig({
  testDir: './tests',
  outputDir: 'test-results',
  timeout: 120_000,
  expect: { timeout: 90_000 },
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? [['line'], ['html', { open: 'never' }]] : 'line',
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://127.0.0.1:4173',
    browserName: 'chromium',
    channel: process.env.CI ? undefined : 'chrome',
    headless: true,
    viewport: { width: 1280, height: 720 },
    locale: 'zh-CN',
    timezoneId: 'Asia/Shanghai',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  webServer: process.env.E2E_BASE_URL ? undefined : {
    command: 'node scripts/static_server.js',
    url: 'http://127.0.0.1:4173/',
    timeout: 10_000,
    reuseExistingServer: false,
    env: { E2E_WEB_DIR: webDir },
  },
});
