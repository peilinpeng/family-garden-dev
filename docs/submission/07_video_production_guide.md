# 07｜正式视频制作与交付

## 已固定规格

- 成片时长：4 分 30 秒（270 秒）；
- 画面：1920×1080、30 fps、16:9；
- 视频：H.264 High Profile、14 Mbps 目标码率、18 Mbps 峰值；
- 音频：AAC、48 kHz、192 kbps；
- 字幕：MP4 内嵌可选简体中文字幕轨，同时保留独立 SRT；
- 画面时钟：固定下午 14:00；
- 数据：`FAMILY_GARDEN_TEST=1` 隔离演示存档，不读写真实家庭账号。

## 一键生成

在仓库根目录执行：

```bash
./tools/record_submission_video.sh
```

默认输出到 `artifacts/submission/video/`（已加入 `.gitignore`）：

- `family_garden_demo_4m30_1080p_h264_zh.mp4`：1080p 审片版，含可开关中文字幕轨；
- `family_garden_demo_contact_sheet.png`：每 30 秒一帧的九宫格复核图；
- `family_garden_demo_ffprobe.txt`：编码、分辨率、帧率与时长证据；
- `family_garden_demo_blackdetect.txt`：持续 1 秒以上的异常黑帧扫描结果；短淡化转场不计异常。

脚本会在编码前单独断言 MJPEG 原片本身达到 `270±0.2` 秒；不能用字幕轨或尾帧重复把短原片
“补成”270 秒。最终 MP4 还会再次验证视频、音频、字幕轨、分辨率和容器时长。
macOS 上脚本会自动使用 `caffeinate` 防止显示休眠/App Nap 跳过静态 UI 帧；录制期间不要手动
最小化或退出 Godot 窗口。

如需保留体积较大的 720p MJPEG 原片，设置 `FG_KEEP_RAW=1`。录制脚本会先生成原片，
成功编码后默认删除它；最终 MP4 和所有中间产物均不进入 Git。

内嵌字幕使用 MP4 原生 `mov_text`，不要求本机 FFmpeg 额外安装 libass。若比赛平台不保留
可选字幕轨，上传时应同时提交独立 SRT，或在最终剪辑软件中把该 SRT 烧录到画面。

## 真实性边界

导演场景复用产品真实 UI、真实布局算法与真实本地数据模型，但为保证镜头稳定，不调用生产账号、
不上传照片，也不把录制夹具伪装成一次新的在线 AI 请求。记忆卡与房间草稿会显示
`source=demo_fixture`。真实 AI、生产 HTTPS 与 CloudBase 链路的验收证据仍以
`06_final_qa_report.md` 和生产 E2E 记录为准。

## 旁白与最终混音

字幕时间轴在 `subtitles/family_garden_zh-CN.srt`。真人旁白按同一时间轴录制，建议：

- 录音峰值不高于 -3 dBFS，综合响度约 -16 LUFS；
- 旁白前后各保留 0.3 秒房间底噪，便于降噪；
- 背景音乐低于旁白 12—16 dB，不覆盖点击、生长和同步提示；
- 不把 AI 生成音色冒充真人团队成员；如使用合成音，必须在提交材料中标注。

收到旁白 WAV 后，可使用以下命令替换审片版音轨：

```bash
ffmpeg -i artifacts/submission/video/family_garden_demo_4m30_1080p_h264_zh.mp4 \
  -i narration.wav -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 192k -ar 48000 \
  -shortest -movflags +faststart artifacts/submission/video/family_garden_demo_final.mp4
```

## 人工终检

自动检查不能替代从头到尾观看。最终提交前仍需一名未参与当天开发的人确认：

1. 没有黑帧、通知、光标乱晃、调试窗口或隐私内容；
2. 字幕无错字，且不遮挡底部导航与状态提示；
3. 旁白与画面语义同步，AI、fallback 和演示夹具的来源没有混淆；
4. 在另一台设备完整播放，声音与画面都正常；
5. 平台重新编码后仍清晰，再保存提交成功页和编号。
