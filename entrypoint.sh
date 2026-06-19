#!/bin/bash
# ============================================================
# llama-server Vulkan MTP 诊断入口
# 启动时打印 Vulkan 设备信息，帮助排查 MTP 性能问题
# ============================================================

echo "=========================================="
echo " llama-server Vulkan 诊断"
echo "=========================================="

# 1. 检查 /dev/dri
echo ""
echo "[1/4] GPU 设备节点检查 (/dev/dri):"
if [ -d /dev/dri ]; then
    ls -la /dev/dri/ 2>&1 | sed 's/^/  /'
else
    echo "  ❌ /dev/dri 不存在！GPU 未透传到容器"
    echo "  请确保 LXC 配置了 lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir"
fi

# 2. vulkaninfo
echo ""
echo "[2/4] Vulkan 设备信息 (vulkaninfo):"
if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>&1 | grep -E "deviceName|driverName|deviceType|apiVersion" | sed 's/^/  /'
else
    echo "  vulkaninfo 不可用"
fi

# 3. 检查 ICD 清单
echo ""
echo "[3/4] Vulkan ICD 清单:"
if [ -d /usr/share/vulkan/icd.d ]; then
    ls /usr/share/vulkan/icd.d/ 2>&1 | sed 's/^/  /'
    for f in /usr/share/vulkan/icd.d/*.json; do
        [ -f "$f" ] && echo "  └─ $(basename $f): $(cat $f | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get(\"ICD\",{}).get(\"path\",\"unknown\"))' 2>/dev/null || echo 'parse error')"
    done
fi

# 4. 确认会用哪个驱动
echo ""
echo "[4/4] ggml-vulkan 模块:"
if [ -f /app/libggml-vulkan.so ]; then
    echo "  ✅ /app/libggml-vulkan.so 存在 ($(ls -lh /app/libggml-vulkan.so | awk '{print $5}'))"
else
    echo "  ⚠️  /app/libggml-vulkan.so 不存在"
fi

echo ""
echo "=========================================="
echo " 启动 llama-server..."
echo "=========================================="

exec /app/llama-server "$@"
