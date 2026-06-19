# ============================================================
# 使用官方预编译 Release 二进制（ubuntu-vulkan）
# 跳过源码编译，直接下载官方构建好的版本
# ============================================================

# === 第一阶段：下载官方 Release 包 ===
FROM ubuntu:26.04 AS downloader

RUN apt-get update && \
    apt-get install -y curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /download
RUN curl -sL \
    "https://github.com/ggerganov/llama.cpp/releases/download/b9724/llama-b9724-bin-ubuntu-vulkan-x64.tar.gz" \
    -o llama-vulkan.tar.gz && \
    tar xzf llama-vulkan.tar.gz && \
    rm llama-vulkan.tar.gz

RUN mkdir -p /app/out && \
    # 复制 llava-server 及其需要的 .so 文件
    cp llama-b9724/llama-server /app/out/ && \
    cp llama-b9724/libllama-server-impl.so /app/out/ && \
    cp llama-b9724/libllama-common.so* /app/out/ && \
    cp llama-b9724/libllama.so* /app/out/ && \
    cp llama-b9724/libggml.so* /app/out/ && \
    cp llama-b9724/libggml-base.so* /app/out/ && \
    cp llama-b9724/libggml-vulkan.so /app/out/ && \
    cp llama-b9724/libmtmd.so* /app/out/ && \
    cp llama-b9724/libllama-cli-impl.so /app/out/ && \
    # 复制 CPU 变体 .so（让运行时自动选最优）
    cp llama-b9724/libggml-cpu-*.so /app/out/

# === 第二阶段：最小运行时 ===
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# 中科大镜像加速
RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 运行时依赖：vulkan loader + 硬件驱动 + openmp
RUN apt-get update && \
    apt-get install -y \
        libvulkan1 \
        mesa-vulkan-drivers \
        libgomp1 \
        ca-certificates \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=downloader /app/out/ /app/

EXPOSE 8080

ENTRYPOINT ["/app/llama-server"]
