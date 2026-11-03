# 浏览器发布验收

运行方式：

```bash
./tools/build_web_release.sh /tmp/family-garden-web-check
E2E_WEB_DIR=/tmp/family-garden-web-check npm --prefix e2e test
```

构建目录必须为空。CI 使用安装好的 Chromium，本机默认 Chrome。

这些测试验证真实导出包的加载、分片失败、音频解锁、Canvas 渲染、横竖屏与照片桥接。
`fixtures/cloud_unavailable.js` 在浏览器网络边界为 `/data_gateway` 返回确定的业务失败
响应，避免资源测试依赖云环境续费或建立真实成员。没有过滤浏览器错误，没有改生产配置。
这只覆盖服务端返回合法失败 JSON 的降级路径，不等同于覆盖 DNS、CORS 或断网错误。

通过本套测试不代表真实云环境健康。发布前仍须运行 `backend/cloudbase` 下相应真实
环境 smoke，并记录环境、版本及结果；当前旧环境返回 `INVALID_ENV`，需登录核实，
不能用此夹具结果解除生产发布阻塞。
