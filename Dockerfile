# ============================================================
# 多阶段构建：llama.cpp + Vulkan 后端
# 支持以 PVE LXC 容器方式运行（含 systemd）
# ============================================================

# === 第一阶段：构建阶段 ===
FROM ubuntu:26.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        libvulkan-dev \
        glslc \
        spirv-headers \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# 编译 llama.cpp，启用 Vulkan 后端
# BUILD_SHARED_LIBS=OFF 将所有代码静态链接进 llama-server，
# 运行时不需要额外的 .so 文件
WORKDIR /app/llama.cpp
RUN mkdir build && cd build && \
    cmake .. -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=OFF && \
    cmake --build . --config Release -j $(nproc)

# 收集产物：只复制单二进制
RUN mkdir -p /app/out && \
    cp build/bin/llama-server /app/out/llama-server


# === 第二阶段：运行阶段（支持 systemd，兼容 LXC） ===
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

RUN apt-get update && \
    apt-get install -y \
        systemd \
        systemd-sysv \
        dbus \
        libvulkan1 \
        libgomp1 \
        ca-certificates \
        curl \
        openssh-server \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 清理不必要的 systemd 服务
RUN rm -f /lib/systemd/system/getty@.service \
          /lib/systemd/system/serial-getty@.service \
          /lib/systemd/system/console-getty.service \
          /lib/systemd/system/cloud-init*.service \
          /lib/systemd/system/cloud-*.service \
          /lib/systemd/system/netplan-*.service \
          /lib/systemd/system/networkd-dispatcher.service \
          /lib/systemd/system/apt-daily*.service \
          /lib/systemd/system/update*.service \
          /lib/systemd/system/unattended-upgrades.service \
          /lib/systemd/system/e2scrub*.service \
          /lib/systemd/system/fstrim*.service \
          /lib/systemd/system/systemd-resolved.service \
          /lib/systemd/system/systemd-timesyncd.service \
          /etc/systemd/system/*.wants/* 2>/dev/null || true

RUN systemctl enable systemd-networkd 2>/dev/null || true

# 创建 llama-server 的 systemd 服务
RUN mkdir -p /app && \
    cat > /etc/systemd/system/llama-server.service << 'SERVICE'
[Unit]
Description=llama.cpp Server (Vulkan)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/app/llama-server
WorkingDirectory=/app
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=65536

# 透传 LXC 环境变量（由 lxc.environment.runtime 传入）
PassEnvironment=LLAMA_ARG_HOST LLAMA_ARG_MODEL LLAMA_ARG_PORT LLAMA_ARG_N_GPU_LAYERS

[Install]
WantedBy=multi-user.target
SERVICE

# 从构建阶段复制编译好的二进制（静态链接，单个文件搞定）
COPY --from=builder /app/out/llama-server /app/llama-server

RUN systemctl enable llama-server.service

EXPOSE 8080

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
