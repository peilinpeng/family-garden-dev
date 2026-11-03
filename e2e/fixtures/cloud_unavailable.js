const { test: base, expect } = require('@playwright/test');

// 资源加载／浏览器桥接测试使用确定的服务端业务失败响应，不创建真实家庭或成员。
// 保留 console/pageerror 断言；生产可用性由真实环境 smoke 单独验收。
const test = base.extend({
  page: async ({ page }, use) => {
    await page.route((url) => url.pathname === '/data_gateway', async (route) => {
      const headers = {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'POST, OPTIONS',
        'access-control-allow-headers': 'authorization, content-type',
      };
      if (route.request().method() === 'OPTIONS') {
        await route.fulfill({ status: 204, headers });
        return;
      }
      await route.fulfill({
        status: 200,
        headers,
        contentType: 'application/json',
        body: JSON.stringify({ ok: false, code: 503, error: 'simulated backend unavailable' }),
      });
    });
    await use(page);
  },
});

module.exports = { test, expect };
