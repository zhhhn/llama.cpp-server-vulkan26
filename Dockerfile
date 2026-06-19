# ============================================================
# 多阶段构建：llama.cpp + Vulkan 后端 (Ubuntu 26.04)
# ============================================================

# === 第一阶段：构建阶段 ===
FROM ubuntu:26.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 更换为中科大镜像源（国内加速）
RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 安装编译依赖
# glslc 和 spirv-headers 是 Vulkan 后端的强制依赖，缺了 cmake 会报错
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

# 克隆 llama.cpp（只拉最新提交，减少体积）
WORKDIR /app
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# 编译 llama.cpp，启用 Vulkan 后端
WORKDIR /app/llama.cpp
RUN mkdir build && cd build && \
    cmake .. -DGGML_VULKAN=ON && \
    cmake --build . --config Release -j $(nproc)

# 收集构建产物
# ggml-vulkan 默认是静态链接到 ggml 中的，
# 所以最终 llama-server 已经包含了 Vulkan 支持，无需额外 .so
RUN mkdir -p /app/out && \
    cp bin/llama-server /app/out/llama-server


# === 第二阶段：运行阶段 ===
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# 更换为中科大镜像源
RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 只安装运行时所需的 Vulkan 库
RUN apt-get update && \
    apt-get install -y \
        libvulkan1 \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 从构建阶段复制编译好的二进制
COPY --from=builder /app/out/llama-server /app/llama-server

WORKDIR /app

EXPOSE 8080

ENTRYPOINT ["./llama-server"]
