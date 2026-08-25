# 63｜M3 CI 质量门禁验收

> 日期：2026-08-02
>
> 分支：`feature/quality-optimization`
>
> 状态：已完成本地验证、GitHub Actions 冷缓存修复与线上完整验收

## 1. 目标与范围

M3 将 M0 的统一回归入口和 M2 的 Web 导出审计接入 GitHub Actions，让功能分支、集成分支
和稳定分支共享同一套可重复质量门禁。

本阶段覆盖：

1. `main`、`dev`、`feature/**` 的 push；
2. 面向 `main` 或 `dev` 的 pull request；
3. 手动 `workflow_dispatch`；
4. Godot 场景、Node 单元测试、Python Schema 契约、生产依赖 critical 漏洞和 Web Release；
5. 失败日志短期留存。

本阶段不部署游戏或云函数，不运行真实 AI、CloudBase、Presence 烟测，不读取项目密钥，也不
自动修改 GitHub 分支保护规则。

## 2. 固定环境

CI 使用 `ubuntu-24.04`，固定以下版本：

| 工具 | 版本 |
|---|---:|
| Godot | 4.7.0 stable |
| Node.js | 22.22.2 |
| Python | 3.13.5 |
| Runner | Ubuntu 24.04 |

Godot 安装步骤同时安装版本匹配的 Web 导出模板，并缓存引擎与模板。工作流另行缓存
`game/.godot` 导入结果，缓存键包含 Godot 版本和 `game/**` 内容哈希；命中旧前缀时仍会执行
`godot --import`，让 Godot 自行更新变更资源。`setup-node` 根据三个生产 lockfile 缓存 npm
下载目录，`setup-python` 根据契约 requirements 缓存 pip 下载目录；依赖安装仍使用
`npm ci` 和独立虚拟环境，避免把可变的 `node_modules` 当作构建结果复用。

## 3. 门禁内容

工作流 `M3 质量门禁` 只有一个必需 job：`全量回归与 Web 导出`，按顺序执行：

1. 恢复 Godot 导入缓存并核对 Godot、Node、npm 和 Python 实际版本；
2. 显式执行 `godot --headless --path game --import`，完成后立即保存导入缓存；
3. `./tools/test_all.sh --bootstrap`，每个执行单元最多运行 180 秒；
4. 三个 Node 工作区执行 `npm audit --omit=dev --audit-level=critical`；
5. `./tools/check_web_export.sh`；
6. 任一步失败时上传测试与导出日志，保留 7 天。

统一回归目前包含 20 个 Godot 测试场景和 4 个后端/契约执行单元。Web 审计继续使用 M2 的
130,000,000 bytes PCK 门禁，并检查动态资源、生产引用边界和导出包启动。

## 4. 安全与资源边界

- 工作流权限仅为 `contents: read`；
- checkout 禁止持久化 Git 凭据；
- 不使用 `pull_request_target`，避免在高权限上下文执行 PR 代码；
- 工作流不引用 `secrets.*`，fork PR 也不会获得项目密钥；
- 所有 Action 固定到完整提交 SHA，并在行尾标记对应发布版本；
- 同一 PR 或分支的新提交会取消旧运行，减少重复 Actions 时长；
- 只在失败时上传纯本地测试日志，且 7 天后过期；
- 冷缓存 job 上限为 45 分钟，资源导入最多 30 分钟，测试步骤最多 10 分钟；
- 每个测试执行单元独立限制 180 秒，避免单场景挂起吞掉整个 job；
- 真实云端冒烟测试继续由对应验收流程显式触发。

## 5. 本地验收

- [x] `actionlint 1.7.12` 检查工作流语法、表达式与 Action 输入；
- [x] `./tools/test_all.sh` 全量回归 24/24 通过，0 失败；
- [x] 三个生产 Node 工作区 critical 漏洞审计通过；
- [x] `./tools/check_web_export.sh` 通过，PCK 为 128,473,164 bytes；
- [x] `git diff --check` 通过且未包含敏感信息；
- [x] 推送后 GitHub Actions 线上完整运行通过。

线上结果通过 GitHub Actions API 与完整 job 日志核验，没有使用本地结果替代。

Data Gateway 因线上 Node.js 18.15 兼容边界继续锁定 `@cloudbase/node-sdk 3.18.3`，本次审计仍
报告该 SDK 的 3 个 high 和 1 个 moderate 传递依赖告警，但 critical 为 0。该风险和迁移边界已在
M1 验收文档记录；CI 使用 `--audit-level=critical` 会完整打印这些告警，同时只阻断 critical，
不会把结果描述成“零漏洞”。

## 6. GitHub Actions 线上验收

最终成功运行：

- 提交：`4e830facc93880bb6bd1f862157d4124c384e3fd`；
- Run：<https://github.com/peilinpeng/family-garden-dev/actions/runs/30741815632>；
- Runner：Ubuntu 24.04；
- Job：`全量回归与 Web 导出`；
- 结果：成功；
- 总耗时：1 分 40 秒；
- Godot 导入缓存：命中；
- 全量回归：24/24 通过，0 失败，用时 37 秒；
- 三个 Node 工作区：critical 漏洞门禁通过；
- Web Release：PCK 为 128,473,164 bytes，完整审计通过。

线上首轮验证同时发现并修复了两个只在全新 Linux runner 暴露的问题：

1. 初始工作流让第一个测试隐式承担全项目资源导入，20 分钟 job 超时；现已改为显式
   `godot --import`、缓存 `game/.godot` 并设置分层超时；
2. GNU `timeout` 不能直接执行 Bash 内部函数，导致三个 Node 测试未启动；现已改为
   `npm --prefix` 外部命令，并在本地和线上确认 24/24 执行单元通过。

失败轮次的日志均用于定位后续最小修复；最终成功轮次证明缓存恢复、版本固定、回归、依赖审计
和 Web 导出链路可以在真实 GitHub-hosted Linux runner 上闭环运行。

## 7. 启用分支保护

首次线上运行通过后，在 GitHub 的 `dev` 与 `main` 分支保护中把
`全量回归与 Web 导出` 设为 required status check。该操作会改变远端仓库合并策略，不由
工作流自动执行，应由仓库管理员确认后完成。

## 8. 后续方向

M3 完成后优先进入 M4 浏览器端关键路径 E2E：在真实 Web 导出中覆盖启动页音频解锁、主场景
进入、地图旅行和至少一条离线核心玩法。E2E 应继续与真实云端烟测分离，默认使用 mock 或
离线模式，避免 PR 自动化产生外部费用。
