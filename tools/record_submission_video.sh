#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
ffmpeg_bin="${FFMPEG_BIN:-$(command -v ffmpeg || true)}"
ffprobe_bin="${FFPROBE_BIN:-$(command -v ffprobe || true)}"
output_dir="${FG_VIDEO_OUTPUT_DIR:-${repo_root}/artifacts/submission/video}"
raw_avi="${output_dir}/family_garden_capture_720p30.avi"
final_mp4="${output_dir}/family_garden_demo_4m30_1080p_h264_zh.mp4"
contact_sheet="${output_dir}/family_garden_demo_contact_sheet.png"
probe_report="${output_dir}/family_garden_demo_ffprobe.txt"
black_report="${output_dir}/family_garden_demo_blackdetect.txt"
subtitle_path="docs/submission/subtitles/family_garden_zh-CN.srt"

if [[ ! -x "$godot_bin" ]]; then
  echo "未找到 Godot：$godot_bin" >&2
  exit 1
fi
if [[ -z "$ffmpeg_bin" || -z "$ffprobe_bin" ]]; then
  echo "未找到 ffmpeg/ffprobe。macOS 可运行：brew install ffmpeg" >&2
  exit 1
fi

mkdir -p "$output_dir"
cd "$repo_root"

echo "[1/5] 录制 1280×720、30 fps 隔离演示原片（8100 帧 / 4:30）"
godot_args=(
  --path game --windowed --position 40,40 --resolution 1280x720 --fixed-fps 30
  --write-movie "$raw_avi" --quit-after 8100
  tools/CaptureSubmissionVideo.tscn
)
if command -v caffeinate >/dev/null 2>&1; then
  # macOS 在显示器休眠或 App Nap 时会跳过 MovieWriter 帧；先声明用户活动，再保持录制进程活跃。
  caffeinate -u -t 2
  FAMILY_GARDEN_TEST=1 FG_CAPTURE_SCREENSHOTS=1 \
    caffeinate -d -i -s "$godot_bin" "${godot_args[@]}"
else
  FAMILY_GARDEN_TEST=1 FG_CAPTURE_SCREENSHOTS=1 \
    "$godot_bin" "${godot_args[@]}"
fi

raw_duration="$($ffprobe_bin -v error -show_entries format=duration -of csv=p=0 "$raw_avi")"
awk -v d="$raw_duration" 'BEGIN { if (d < 269.8 || d > 270.2) exit 1 }' || {
  echo "原始 AVI 时长不是 270±0.2 秒：${raw_duration}。停止编码，避免生成冻结尾帧。" >&2
  exit 1
}

echo "[2/5] 编码 1920×1080 H.264/AAC，并内嵌可选中文字幕轨"
"$ffmpeg_bin" -y -hide_banner -loglevel warning \
  -i "$raw_avi" -i "$subtitle_path" -t 270 \
  -map 0:v:0 -map 0:a:0 -map 1:0 \
  -vf "scale=1920:1080:flags=neighbor" \
  -c:v libx264 -preset slow -profile:v high -level 4.1 -pix_fmt yuv420p \
  -b:v 14M -maxrate 18M -bufsize 28M -g 60 -movflags +faststart \
  -c:a aac -b:a 192k -ar 48000 \
  -c:s mov_text -metadata:s:s:0 language=chi -metadata:s:s:0 title="简体中文" \
  "$final_mp4"

echo "[3/5] 验证编码、分辨率、帧率与时长"
"$ffprobe_bin" -v error \
  -show_entries format=duration,size,bit_rate:stream=index,codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels \
  -of default=noprint_wrappers=1 "$final_mp4" | tee "$probe_report"

duration="$($ffprobe_bin -v error -show_entries format=duration -of csv=p=0 "$final_mp4")"
video_codec="$($ffprobe_bin -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$final_mp4")"
audio_codec="$($ffprobe_bin -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$final_mp4")"
subtitle_codec="$($ffprobe_bin -v error -select_streams s:0 -show_entries stream=codec_name -of csv=p=0 "$final_mp4")"
dimensions="$($ffprobe_bin -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$final_mp4")"

awk -v d="$duration" 'BEGIN { if (d < 269.8 || d > 270.2) exit 1 }' || {
  echo "成片时长不是 270±0.2 秒：${duration}" >&2
  exit 1
}
[[ "$video_codec" == "h264" ]] || { echo "视频编码不是 H.264：$video_codec" >&2; exit 1; }
[[ "$audio_codec" == "aac" ]] || { echo "音频编码不是 AAC：$audio_codec" >&2; exit 1; }
[[ "$subtitle_codec" == "mov_text" ]] || { echo "字幕轨不是 mov_text：$subtitle_codec" >&2; exit 1; }
[[ "$dimensions" == "1920x1080" ]] || { echo "分辨率不是 1920x1080：$dimensions" >&2; exit 1; }

echo "[4/5] 生成 30 秒间隔接触表并扫描超过 1 秒的异常黑帧"
"$ffmpeg_bin" -y -hide_banner -loglevel error -i "$final_mp4" \
  -vf "fps=1/30,scale=640:360:flags=neighbor,tile=3x3" -frames:v 1 "$contact_sheet"
"$ffmpeg_bin" -hide_banner -nostats -i "$final_mp4" \
  -vf "blackdetect=d=1.0:pic_th=0.98" -an -f null - 2>&1 \
  | grep -E "black_start|black_end|black_duration" > "$black_report" || true

echo "[5/5] 清理可重建的 AVI 中间文件"
if [[ "${FG_KEEP_RAW:-0}" != "1" ]]; then
  rm -f "$raw_avi"
fi

echo "完成：$final_mp4"
echo "接触表：$contact_sheet"
echo "编码报告：$probe_report"
echo "黑帧报告：$black_report"
