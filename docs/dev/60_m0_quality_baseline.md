# 60｜M0 质量基线与本地全量回归

> 基线日期：2026-07-31
>
> 基线分支：`feature/quality-optimization`
>
> 基线提交：`e58a821`
>
> 目标：修复已知回归、建立单一测试入口，并为后续安全与可靠性优化提供可重复的本地基线。

## 1. M0 范围

本阶段只处理测试基线，不修改 AI 接口、云端配置、上传逻辑、主场景或存档结构：

1. 同步固定记忆花圃的视觉测试契约；
2. 建立 `tools/test_all.sh` 本地全量测试入口；
3. 覆盖全部 Godot 测试、三个 Node 工作区和 AI JSON Schema 契约；
4. 验证 Web Release 可以导出，并记录当前包体积；
5. 明确普通回归不访问真实云端或收费服务。

## 2. 已修复的基线回归

提交 `0def716` 已把记忆花圃改为独立、永久存在的固定景观：

- 使用受控花圃资产；
- Sprite 可见；
- 点击区跟随实际渲染尺寸；
- 提供玩家碰撞体；
- 注册到 `fixed_garden_landmark` 分组。

旧测试仍要求隐藏 Sprite 并复用背景花丛，同时硬编码点击区宽度至少为 180，
与当前实现不一致。M0 将测试同步为验证当前产品契约：

- 独立花圃可见；
- 固定景观分组和元数据正确；
- 点击区等于实际渲染尺寸且不小于 80×80；
- 玩家碰撞体存在。

业务实现和现有美术资产未修改。

## 3. 统一测试入口

首次准备环境：

```bash
./tools/test_all.sh --bootstrap
```

日常全量回归：

```bash
./tools/test_all.sh
```

默认测试入口会：

1. 校验 Godot 4.7、Node.js 20.19+、npm、Python 3 和 `jsonschema`；
2. 按文件名顺序执行 `game/tests/` 下全部 `.tscn`；
3. 执行 AI Gateway Node 测试；
4. 执行 Gate 1 Python JSON Schema 契约测试；
5. 执行 Data Gateway Node 测试；
6. 执行 Presence Relay Node 测试；
7. 汇总通过数、失败数、耗时和失败日志。

`--bootstrap` 会执行三个工作区的 `npm ci`，并在仓库根目录创建 `.venv` 安装
Python 契约依赖。`.venv` 已加入 `.gitignore`。

## 4. 基线环境

| 项目 | 版本 |
|---|---|
| 操作系统 | macOS 15.6（arm64） |
| 处理器 | Apple M4 |
| Godot | 4.7.stable.official.5b4e0cb0f |
| Node.js | v22.22.2 |
| npm | 10.9.7 |
| Python | 3.13.5 |
| jsonschema | 4.26.0 |

Node.js 基线环境高于项目最低要求 20.19。CI 建立后仍应固定明确版本，避免只依赖个人机器。

## 5. 全量回归结果

执行时间：2026-07-31。

| 测试层 | 结果 | 说明 |
|---|---:|---|
| Godot 场景测试 | 19/19 通过 | 包含 Gate 4、角色、家庭树、农场、厨房、房间、地图、关怀模式和 Web UI |
| AI Gateway Node | 35/35 通过 | fake provider、鉴权、内容安全、限流、幂等、fallback 和契约编排 |
| Gate 1 Python 契约 | 通过 | 13 个 Schema，5 组生成请求/mock、1 组内容审核及拒绝场景 |
| Data Gateway Node | 39/39 通过 | 身份、家庭隔离、图片、CRUD、库存和农场 |
| Presence Relay Node | 6/6 通过 | 鉴权、家庭隔离、移动与世界事件 |
| 统一脚本执行单元 | 23/23 通过 | 19 个 Godot 场景 + 4 组后端/契约任务 |

统一脚本首次实测总耗时为 62 秒；依赖重新安装、缓存就绪后复测为 40 秒。
Node 测试合计 80/80 通过。脚本计时不包含 `--bootstrap` 的依赖下载时间。

## 6. Web Release 导出基线

执行命令：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game \
  --export-release Web ../export_web/index.html
```

导出成功，产物总大小为 172,899,142 bytes（约 164.9 MiB）：

| 文件 | 大小 |
|---|---:|
| `index.pck` | 132,935,156 bytes（约 126.8 MiB） |
| `index.wasm` | 39,509,339 bytes（约 37.7 MiB） |
| `index.js` | 279,815 bytes |
| `index.html` | 9,878 bytes |

当前 Web preset 使用 `export_filter="all_resources"`，因此 PCK 会包含测试、工具和未被主流程
使用的资源。M0 只记录基线，不调整导出范围；包体积优化应作为后续独立任务处理并验证资源完整性。

## 7. M0.1 依赖安全修复

M0 首次执行 `npm audit --omit=dev` 时发现：

```text
ajv@8.20.0 → fast-uri@3.1.3
```

`fast-uri 3.1.3` 受 GHSA-v2hh-gcrm-f6hx / CVE-2026-16221 影响。该问题可能使
URI 校验器与 Node WHATWG `URL` 对反斜杠 authority 分隔符产生不同解释，造成
host allowlist、SSRF 过滤或重定向校验与实际请求目标不一致。

M0.1 将 lockfile 中的传递依赖最小升级到官方修复版本 `fast-uri 3.1.4`，没有升级
AJV、腾讯云 SDK 或其他生产依赖。同时增加反斜杠 host-confusion 图片地址回归用例，
确认应用层 `assertSafeImageUrl` 仍按 Node 实际请求语义拒绝伪装域名。

修复后：

- `npm ls fast-uri ajv --all` 显示 `ajv@8.20.0 → fast-uri@3.1.4`；
- `npm audit --omit=dev` 返回 0 个漏洞；
- AI Node 测试和 Gate 1 Python 契约测试通过；
- 项目统一全量回归通过。

## 8. 已知限制

1. 普通回归不调用真实 AI、CloudBase、腾讯内容安全或线上 Presence；
2. 尚未建立 CI，当前脚本先保证本地执行方式唯一；
3. 尚未加入浏览器自动化 E2E，Web 部分目前验证导出成功和 Godot UI 回归；
4. 测试耗时是单次本机结果，不代表 CI 或其他设备性能；
5. 仓库现有未跟踪副本和提交材料不属于 M0，没有删除或修改。

## 9. M0 完成标准

- [x] 已知花圃回归测试修复；
- [x] 19 个 Godot 测试场景全部通过；
- [x] 三个 Node 工作区测试全部通过；
- [x] AI Python 契约测试通过；
- [x] 一条命令可运行完整本地回归；
- [x] Web Release 导出成功并记录包体积；
- [x] README 已指向统一测试入口；
- [x] `fast-uri` high 级告警修复，生产依赖审计为 0；
- [ ] CI 门禁——进入后续 M3 阶段。

## 10. 下一阶段入口

M0 通过后，可进入 M1 照片隐私迁移。开始 M1 前应先运行：

```bash
./tools/test_all.sh
```

M1 完成后必须再次执行同一命令，并补充照片跨家庭隔离、受控解析和删除测试。
