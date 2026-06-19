# ============================================================
# 多阶段构建：llama.cpp + Vulkan 后端 (Ubuntu 26.04)
# ============================================================

# === 第一阶段：构建阶段 ===
FROM ubuntu:26.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 更换为中科大镜像源（国内加速）
RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 安装编译依赖
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        libvulkan-dev \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 克隆 llama.cpp（只拉最新提交，减少体积）
WORKDIR /app
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# 编译 llama.cpp，启用 Vulkan 后端
WORKDIR /app/llama.cpp
RUN mkdir build && cd build && \
    cmake .. -DGGML_VULKAN=ON && \
    cmake --build . --config Release -j $(nproc)

# 收集构建产物到 /app/out，方便复制
RUN mkdir -p /app/out && \
    cp bin/llama-server /app/out/ && \
    cp build/libggml-vulkan.so /app/out/ 2>/dev/null || true


# === 第二阶段：运行阶段 ===
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# 更换为中科大镜像源
RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 只安装运行时所需的 Vulkan 库，大幅缩小镜像体积
RUN apt-get update && \
    apt-get install -y \
        libvulkan1 \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 从构建阶段复制编译好的二进制和库
COPY --from=builder /app/out/llama-server /app/llama-server
COPY --from=builder /app/out/libggml-vulkan.so /app/libggml-vulkan.so 2>/dev/null || true

WORKDIR /app

# 设置库路径，确保 Vulkan 库能被加载
ENV LD_LIBRARY_PATH=/app:$LD_LIBRARY_PATH

EXPOSE 8080

ENTRYPOINT ["./llama-server"]
