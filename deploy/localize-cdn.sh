#!/usr/bin/env bash
# 把 ECharts / SheetJS 从国外 CDN 下载到 vendor/，并让 index.html 优先加载本地文件。
# 原因：国内网络访问 cdn.jsdelivr.net 时快时慢甚至超时，会导致 K 线图空白、Excel 导入无反应。
# 改 index.html 前会自动备份为 index.html.bak，可随时回滚。
#
# 用法：在 stock-quotes 目录下执行  ./deploy/localize-cdn.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$DIR")"
cd "$ROOT"

VENDOR="$ROOT/vendor"
mkdir -p "$VENDOR"

download() {   # download <url> <target>
  local url="$1" target="$2"
  echo "    尝试 $url"
  curl -fsSL --max-time 60 "$url" -o "$target" 2>/dev/null || return 1
  local size
  size=$(wc -c < "$target" | tr -d ' ')
  if [[ "$size" -lt 100000 ]]; then
    echo "    下载内容异常（${size} 字节），换下一个源"
    rm -f "$target"
    return 1
  fi
  echo "    已保存 $(basename "$target")（${size} 字节）"
  return 0
}

echo "==> 下载 echarts.min.js（5.5.1）"
if [[ ! -s "$VENDOR/echarts.min.js" ]]; then
  download "https://registry.npmmirror.com/echarts/5.5.1/files/dist/echarts.min.js" "$VENDOR/echarts.min.js" \
    || download "https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js" "$VENDOR/echarts.min.js" \
    || download "https://unpkg.com/echarts@5.5.1/dist/echarts.min.js" "$VENDOR/echarts.min.js" \
    || { echo "echarts 下载失败，请手动放置到 vendor/echarts.min.js"; exit 1; }
else
  echo "    已存在，跳过"
fi

echo "==> 下载 xlsx.full.min.js（0.18.5）"
if [[ ! -s "$VENDOR/xlsx.full.min.js" ]]; then
  download "https://registry.npmmirror.com/xlsx/0.18.5/files/dist/xlsx.full.min.js" "$VENDOR/xlsx.full.min.js" \
    || download "https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js" "$VENDOR/xlsx.full.min.js" \
    || download "https://unpkg.com/xlsx@0.18.5/dist/xlsx.full.min.js" "$VENDOR/xlsx.full.min.js" \
    || { echo "xlsx 下载失败，请手动放置到 vendor/xlsx.full.min.js"; exit 1; }
else
  echo "    已存在，跳过"
fi

echo "==> 修改 index.html 优先使用本地 vendor/"
python3 - <<'PY'
import io, os, re, shutil

html_path = "index.html"
src = io.open(html_path, encoding="utf-8").read()

if "vendor/echarts.min.js" in src and "vendor/xlsx.full.min.js" in src:
    print("    已经是本地优先，无需修改")
    raise SystemExit(0)

shutil.copyfile(html_path, html_path + ".bak")
print("    已备份 index.html.bak")

# 1) ECharts：把本地文件插到 CDN 源前面（保留 CDN 作为兜底）
old_echarts = '''      var urls = [
        "https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js",
        "https://unpkg.com/echarts@5.5.1/dist/echarts.min.js"
      ];'''
new_echarts = '''      var urls = [
        "vendor/echarts.min.js",
        "https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js",
        "https://unpkg.com/echarts@5.5.1/dist/echarts.min.js"
      ];'''
if old_echarts in src:
    src = src.replace(old_echarts, new_echarts)
    print("    ECharts 已改为本地优先")
else:
    print("    ⚠️ 未匹配到 ECharts 加载代码，请手动检查 loadECharts()")

# 2) XLSX：原来只有单个 CDN 源且无兜底，改成多源顺序降级
old_xlsx = '''      var s = document.createElement("script");
      s.src = "https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js";
      s.onload = function () { resolve(); };
      s.onerror = function () { reject(new Error("xlsx load failed")); };
      document.head.appendChild(s);'''
new_xlsx = '''      var urls = [
        "vendor/xlsx.full.min.js",
        "https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js",
        "https://unpkg.com/xlsx@0.18.5/dist/xlsx.full.min.js"
      ];
      (function tryNext(i) {
        if (i >= urls.length) { reject(new Error("xlsx load failed")); return; }
        var s = document.createElement("script");
        s.src = urls[i];
        s.onload = function () { resolve(); };
        s.onerror = function () { tryNext(i + 1); };
        document.head.appendChild(s);
      })(0);'''
if old_xlsx in src:
    src = src.replace(old_xlsx, new_xlsx)
    print("    XLSX 已改为本地优先 + CDN 兜底")
else:
    print("    ⚠️ 未匹配到 XLSX 加载代码，请手动检查 loadXLSXLib()")

io.open(html_path, "w", encoding="utf-8").write(src)
PY

cat <<'EOF'

完成。接下来：
  ./deploy/deploy.sh     # 把 vendor/ 和 index.html 一起推到服务器

回滚：cp index.html.bak index.html
EOF
