# 使用 Ubuntu 26.04 LTS 作为基础镜像，默认集成了 Mesa 26.0.x
FROM ubuntu:26.04

# 设置环境变量，避免安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 更换为中科大镜像源，加速国内访问
RUN sed -i 's@//archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 1. 更新系统并安装构建 llama.cpp 所需的依赖
#    包括编译工具链、CMake、Git 以及 Vulkan 相关的开发包
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        wget \
        libvulkan-dev \
        vulkan-validationlayers \
        mesa-utils \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2. 克隆 llama.cpp 仓库
WORKDIR /app
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# 3. 编译 llama.cpp，并启用 Vulkan 后端
WORKDIR /app/llama.cpp
RUN mkdir build && cd build && \
    cmake .. -DGGML_VULKAN=ON && \
    cmake --build . --config Release -j $(nproc)

# 4. 为了方便使用，将编译好的 llama-server 和库文件复制到 /app 目录
RUN cp bin/llama-server /app/ && \
    cp libggml-vulkan.so /app/

# 5. 设置工作目录和默认命令
WORKDIR /app
# 暴露 llama-server 的默认端口
EXPOSE 8080

# 容器启动时运行 llama-server
ENTRYPOINT ["./llama-server"]
