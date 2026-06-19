# ============================================================
# 多阶段构建：llama.cpp + Vulkan 后端
# 用于 PVE LXC，entrypoint 直接启动 llama-server
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

# 单二进制，静态链接主库
# GGML_NATIVE=ON：使用构建机的 CPU 优化（AVX2/FMA 等），
# 确保 MTP 采样循环不卡在通用 CPU 路径上
WORKDIR /app/llama.cpp
RUN mkdir build && cd build && \
    cmake .. \
        -DGGML_VULKAN=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_NATIVE=ON \
        && \
    cmake --build . --config Release -j $(nproc)

RUN mkdir -p /app/out && \
    cp build/bin/llama-server /app/out/llama-server


# === 第二阶段：最小运行时 ===
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 只装最少的运行时库
RUN apt-get update && \
    apt-get install -y \
        libvulkan1 \
        libgomp1 \
        ca-certificates \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/out/llama-server /app/llama-server

EXPOSE 8080

ENTRYPOINT ["/app/llama-server"]
