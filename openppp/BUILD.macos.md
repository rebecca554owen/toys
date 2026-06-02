# 在 macOS 上编译 openppp2 ppp 二进制

本页说明如何在 macOS (Apple Silicon) 上从源码编译出 `ppp` 可执行文件。

## 1. 环境要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| Xcode Command Line Tools | 任意 | 提供 `clang`/`clang++`、`make`、`ar`、`ranlib` |
| CMake | ≥ 3.20 | 生成 Ninja 构建文件 |
| Ninja | 任意 | 构建系统（CMake 自动调用） |
| Python | 3.x | jemalloc `autogen.sh` 需要 |

> **注意**：第三方库（Boost、OpenSSL、jemalloc）**不会**随仓库提供，均需从源码下载并编译生成。

## 2. 源码仓库位置

| 仓库 | 默认路径 | 用途 |
|------|----------|------|
| openppp2 | `~/Documents/GitHub/openppp2` | 主仓库，包含 ppp 源码和 CMakeLists.txt |
| toys | `~/Documents/GitHub/toys` | 包含本文档，不参与编译 |

## 3. 第三方依赖

所有产物统一存放在 `openppp2/third-party/` 下：

| 库 | 版本 | 产物目录 | 说明 |
|----|------|----------|------|
| Boost | 1.87.0 | `third-party/boost/stage/lib/` | 静态库，需从源码编译 |
| jemalloc | 5.3.0 | `third-party/jemalloc/lib/` | 静态库，需从源码编译 |
| OpenSSL | 4.0.0 | `third-party/openssl/lib/` | 静态库，需从源码编译 |

## 4. 编译第三方库

执行顺序：**Boost → jemalloc → OpenSSL**（与 Actions workflow 一致）。

产物已存在时会自动跳过，重复执行可省时。

```bash
cd ~/Documents/GitHub/openppp2/third-party
```

### 4.1 Boost 1.87.0

```bash
if [ -f boost/stage/lib/libboost_system.a ] && [ -f boost/stage/lib/libboost_context.a ]; then
  echo "跳过：boost 产物已存在"
else
  # 下载并解压
  curl -L -o boost.tar.bz2 "https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.bz2"
  tar -xjf boost.tar.bz2
  rm -rf boost boost.tar.bz2
  mv boost_1_86_0 boost

  # 配置工具集（写入 project-config.jam）
  cat > boost/project-config.jam <<'JAM'
using clang : darwin
  : /usr/bin/clang++
  : <target-os>darwin
    <architecture>arm
    <address-model>64
    <binary-format>mach-o
    <threading>multi
    <link>static
    <runtime-link>shared
    <cxxflags>-std=c++17 -fPIC
  ;
JAM

  # 生成 b2 引擎
  cd boost && ./bootstrap.sh >/dev/null 2>&1 && cd ..

  # 编译（产物输出到 stage/lib/）
  rm -rf boost/bin.v2 boost/stage
  cd boost
  ./b2 \
    --build-dir=bin.v2 \
    --stagedir=stage \
    toolset=clang-darwin \
    architecture=arm \
    address-model=64 \
    link=static \
    threading=multi \
    runtime-link=shared \
    --without-mpi \
    --without-python \
    variant=release \
    -j$(sysctl -n hw.logicalcpu) \
    stage
  cd ..
fi

# 验证产物
file boost/stage/lib/libboost_system.a
file boost/stage/lib/libboost_context.a
```

输出应包含 `current ar archive`。

### 4.2 jemalloc 5.3.0

```bash
if [ -f jemalloc/lib/libjemalloc.a ]; then
  echo "跳过：jemalloc 产物已存在"
else
  # 下载并解压
  curl -L -o jemalloc.tar.bz2 "https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2"
  tar -xjf jemalloc.tar.bz2
  rm -rf jemalloc jemalloc.tar.bz2
  mv jemalloc-* jemalloc

  # 编译（静态库）
  cd jemalloc
  ./autogen.sh --with-jemalloc-prefix=je_ --disable-shared --enable-static
  make -j$(sysctl -n hw.logicalcpu)
  cd ..
fi

# 验证
file jemalloc/lib/libjemalloc.a
```

输出应包含 `current ar archive`。

### 4.3 OpenSSL 4.0.0

```bash
if [ -f openssl/lib/libssl.a ] && [ -f openssl/lib/libcrypto.a ]; then
  echo "跳过：openssl 产物已存在"
else
  # 下载并解压
  curl -L -o openssl.tar.gz "https://github.com/openssl/openssl/releases/download/openssl-4.0.0/openssl-4.0.0.tar.gz"
  tar -xzf openssl.tar.gz
  rm -rf openssl openssl-src openssl.tar.gz
  mv openssl-* openssl-src

  # 配置并编译（产物直接输出到 third-party/openssl/）
  cd openssl-src
  CC=/usr/bin/clang RANLIB=/usr/bin/ranlib AR=/usr/bin/ar \
    ./Configure darwin64-arm64-cc \
    --prefix="$PWD/../openssl" \
    no-shared no-tests
  make -j$(sysctl -n hw.logicalcpu) RANLIB=/usr/bin/ranlib AR=/usr/bin/ar
  make install_sw RANLIB=/usr/bin/ranlib AR=/usr/bin/ar
  cd ..

  # 标准化库布局（与 Actions workflow 一致）
  ln -sf lib/libssl.a   openssl/libssl.a
  ln -sf lib/libcrypto.a openssl/libcrypto.a
fi

# 验证
file openssl/lib/libssl.a
file openssl/lib/libcrypto.a
```

输出应包含 `current ar archive`。

## 5. 配置并构建 ppp

```bash
cd ~/Documents/GitHub/openppp2

rm -rf build-macos
mkdir -p build-macos
cd build-macos

CC=/usr/bin/cc CXX=/usr/bin/c++ \
cmake \
  -DTHIRD_PARTY_LIBRARY_DIR=../third-party \
  -DPLATFORM_SYSTEM_DARWIN=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -G Ninja ..

ninja ppp
```

## 6. 产物

构建完成后，可执行文件位于：

```
openppp2/bin/ppp
```

验证版本：

```bash
openppp2/bin/ppp version
```

正常输出应包含：

```
Version:      2.0.0.0
DEPENDENCIES:
    boost@1.86, openssl@4.0, jemalloc@5.3
```

## 7. 关键说明

- **CMake 路径约定**：`CMakeLists.txt` 引用 `${THIRD_PARTY_LIBRARY_DIR}/openssl/libssl.a`，因此 OpenSSL 编译后必须执行 normalize 软链步骤（第 4.3 节），否则链接失败。
- **工具集标识**：Boost.Build 使用 `clang-darwin`（不是 `clang-macos`），否则会报版本解析错误。
- **bootstrap.sh**：必须先生成 b2 引擎，否则 `./b2` 不存在。
- **构建目录**：macOS 使用 `build-macos/`，Android 使用 `build-android/`，两者互不干扰。
- **OpenSSL 参数**：必须加 `no-module` 或 `no-tests`（取决于版本），否则 `no-shared` 与 provider `.so` 冲突。
- **编译工具**：显式指定 `CC=/usr/bin/clang RANLIB=/usr/bin/ranlib AR=/usr/bin/ar`，避免 NDK 残留工具链污染。
