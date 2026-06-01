#!/bin/bash

# Copyright  : Copyright (C) 2017 ~ 2035 SupersocksR ORG. All rights reserved.
# Description: PPP PRIVATE NETWORK(TM) 2 - Android NDK local build script.
# Author     : OpenCode.
# Date-Time  : 2026/05/04

set -e

# ============================================================================
# 配置区域 - 根据本地环境修改
# ============================================================================

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# NDK 和第三方库路径
NDK_ROOT="${NDK_ROOT:-$HOME/Library/Android/sdk/ndk/29.0.14206865}"
THIRD_PARTY_DIR="${THIRD_PARTY_DIR:-$PROJECT_ROOT/third-party}"
ANDROID_CMAKE="${ANDROID_CMAKE:-$HOME/Library/Android/sdk/cmake/3.22.1/bin/cmake}"
ANDROID_API="${ANDROID_API:-21}"

BOOST_VERSION="${BOOST_VERSION:-1.86.0}"
OPENSSL_VERSION="${OPENSSL_VERSION:-4.0.0}"
BOOST_SRC_DIR="${BOOST_SRC_DIR:-$THIRD_PARTY_DIR/boost-src}"
OPENSSL_SRC_DIR="${OPENSSL_SRC_DIR:-$THIRD_PARTY_DIR/openssl-src}"

TOOLCHAIN_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    TOOLCHAIN_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/darwin-arm64"
fi
NDK_REVISION="$(sed -n 's/^Pkg.Revision = //p' "$NDK_ROOT/source.properties" 2>/dev/null | tr -c 'A-Za-z0-9._-' '_')"
NDK_REVISION="${NDK_REVISION:-unknown}"

# ============================================================================
# 函数定义
# ============================================================================

print_help() {
    echo "OpenPPP2 Android NDK 本地构建脚本"
    echo ""
    echo "用法:"
    echo "    $0 [选项]"
    echo ""
    echo "选项:"
    echo "    arm64    - 编译 arm64-v8a (默认)"
    echo "    arm      - 编译 armeabi-v7a"
    echo "    x86      - 编译 x86"
    echo "    x64      - 编译 x86_64"
    echo "    all      - 编译所有架构"
    echo "    clean    - 清理构建目录"
    echo "    help     - 显示此帮助"
    echo ""
    echo "环境变量:"
    echo "    NDK_ROOT         - NDK 路径 (默认: ~/Library/Android/sdk/ndk/29.0.14206865)"
    echo "    THIRD_PARTY_DIR  - 第三方库路径 (默认: ./third-party)"
    echo "    ANDROID_CMAKE    - Android SDK CMake 路径 (默认: ~/Library/Android/sdk/cmake/3.22.1/bin/cmake)"
    echo "    ANDROID_API      - Android API Level (默认: 21)"
    echo "    BOOST_VERSION    - Boost 版本 (默认: 1.86.0)"
    echo "    OPENSSL_VERSION  - OpenSSL 版本 (默认: 4.0.0)"
    echo ""
    echo "示例:"
    echo "    $0 arm64"
    echo "    NDK_ROOT=/path/to/ndk THIRD_PARTY_DIR=/tmp/third-party $0 all"
}

check_tools() {
    echo "检查工具链..."

    if [ ! -d "$NDK_ROOT" ]; then
        echo "错误: NDK 目录不存在: $NDK_ROOT"
        echo "请先通过 Android Studio 或 sdkmanager 安装 NDK 29.0.14206865"
        exit 1
    fi

    if [ ! -f "$NDK_ROOT/build/cmake/android.toolchain.cmake" ]; then
        echo "错误: 找不到 CMake 工具链文件: $NDK_ROOT/build/cmake/android.toolchain.cmake"
        exit 1
    fi

    if [ ! -d "$TOOLCHAIN_DIR/bin" ]; then
        echo "错误: 找不到 Android NDK LLVM 工具链: $NDK_ROOT/toolchains/llvm/prebuilt"
        exit 1
    fi

    if [ ! -x "$ANDROID_CMAKE" ]; then
        echo "错误: 找不到 Android SDK CMake: $ANDROID_CMAKE"
        exit 1
    fi

    for tool in curl make perl tar; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "错误: $tool 未安装"
            exit 1
        fi
    done

    echo "工具链检查通过"
}

normalize_abi() {
    case "$1" in
        arm64)
            PPP_ABI="aarch64"
            ANDROID_ABI_NAME="arm64-v8a"
            OPENSSL_TARGET="android-arm64"
            CLANG_TRIPLE="aarch64-linux-android"
            BOOST_TOOLSET_SUFFIX="androidarm64"
            BOOST_ARCHITECTURE="arm"
            BOOST_ADDRESS_MODEL="64"
            BOOST_ABI="aapcs"
            OPENSSL_OUT_DIR="$THIRD_PARTY_DIR/openssl-arm64"
            ;;
        arm)
            PPP_ABI="armv7a"
            ANDROID_ABI_NAME="armeabi-v7a"
            OPENSSL_TARGET="android-arm"
            CLANG_TRIPLE="armv7a-linux-androideabi"
            BOOST_TOOLSET_SUFFIX="androidarm"
            BOOST_ARCHITECTURE="arm"
            BOOST_ADDRESS_MODEL="32"
            BOOST_ABI="aapcs"
            OPENSSL_OUT_DIR="$THIRD_PARTY_DIR/openssl-armeabi-v7a"
            ;;
        x86)
            PPP_ABI="x86"
            ANDROID_ABI_NAME="x86"
            OPENSSL_TARGET="android-x86"
            CLANG_TRIPLE="i686-linux-android"
            BOOST_TOOLSET_SUFFIX="androidx86"
            BOOST_ARCHITECTURE="x86"
            BOOST_ADDRESS_MODEL="32"
            BOOST_ABI="sysv"
            OPENSSL_OUT_DIR="$THIRD_PARTY_DIR/openssl-x86"
            ;;
        x64)
            PPP_ABI="x64"
            ANDROID_ABI_NAME="x86_64"
            OPENSSL_TARGET="android-x86_64"
            CLANG_TRIPLE="x86_64-linux-android"
            BOOST_TOOLSET_SUFFIX="androidx64"
            BOOST_ARCHITECTURE="x86"
            BOOST_ADDRESS_MODEL="64"
            BOOST_ABI="sysv"
            OPENSSL_OUT_DIR="$THIRD_PARTY_DIR/openssl-x86_64"
            ;;
        *)
            echo "错误: 未知 ABI '$1'"
            exit 1
            ;;
    esac

    BOOST_OUT_DIR="$THIRD_PARTY_DIR/boost/$ANDROID_ABI_NAME"
}

boost_context_has_fcontext() {
    local context_lib="$BOOST_OUT_DIR/libboost_context.a"
    local nm_output

    if [ ! -f "$context_lib" ] || [ ! -x "$TOOLCHAIN_DIR/bin/llvm-nm" ]; then
        return 1
    fi

    nm_output="$("$TOOLCHAIN_DIR/bin/llvm-nm" -g "$context_lib")"
    printf '%s\n' "$nm_output" | grep -Eq ' (make_fcontext)$' &&
        printf '%s\n' "$nm_output" | grep -Eq ' (jump_fcontext)$' &&
        printf '%s\n' "$nm_output" | grep -Eq ' (ontop_fcontext)$'
}

cpu_count() {
    sysctl -n hw.logicalcpu 2>/dev/null || nproc 2>/dev/null || echo 4
}

ensure_boost_source() {
    local expected_lib_version
    expected_lib_version="$(printf '%s' "$BOOST_VERSION" | sed 's/\./_/g')"

    if [ -f "$BOOST_SRC_DIR/boost/version.hpp" ] &&
        grep -q "BOOST_LIB_VERSION \"$expected_lib_version\"" "$BOOST_SRC_DIR/boost/version.hpp"; then
        return
    fi

    echo "准备 Boost $BOOST_VERSION 源码..."
    local boost_archive="$THIRD_PARTY_DIR/boost_${expected_lib_version}.tar.bz2"
    local boost_extract="$THIRD_PARTY_DIR/boost_${expected_lib_version}"
    mkdir -p "$THIRD_PARTY_DIR"

    if [ ! -f "$boost_archive" ]; then
        curl -L --fail -o "$boost_archive" \
            "https://archives.boost.io/release/$BOOST_VERSION/source/boost_${expected_lib_version}.tar.bz2"
    fi

    rm -rf "$boost_extract" "$BOOST_SRC_DIR"
    tar -xjf "$boost_archive" -C "$THIRD_PARTY_DIR"
    mv "$boost_extract" "$BOOST_SRC_DIR"
}

ensure_openssl_source() {
    if [ -f "$OPENSSL_SRC_DIR/Configure" ]; then
        return
    fi

    echo "准备 OpenSSL $OPENSSL_VERSION 源码..."
    local openssl_archive="$THIRD_PARTY_DIR/openssl-$OPENSSL_VERSION.tar.gz"
    local openssl_extract="$THIRD_PARTY_DIR/openssl-$OPENSSL_VERSION"
    mkdir -p "$THIRD_PARTY_DIR"

    if [ ! -f "$openssl_archive" ]; then
        curl -L --fail -o "$openssl_archive" \
            "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
    fi

    rm -rf "$openssl_extract" "$OPENSSL_SRC_DIR"
    tar -xzf "$openssl_archive" -C "$THIRD_PARTY_DIR"
    mv "$openssl_extract" "$OPENSSL_SRC_DIR"
}

build_openssl() {
    if [ -f "$OPENSSL_OUT_DIR/lib/libssl.a" ] && [ -f "$OPENSSL_OUT_DIR/lib/libcrypto.a" ]; then
        echo "OpenSSL 已存在: $OPENSSL_OUT_DIR"
        return
    fi

    ensure_openssl_source

    echo "编译 OpenSSL: $ANDROID_ABI_NAME"
    rm -rf "$OPENSSL_OUT_DIR"
    mkdir -p "$OPENSSL_OUT_DIR"

    (
        cd "$OPENSSL_SRC_DIR"
        export ANDROID_NDK_HOME="$NDK_ROOT"
        export ANDROID_NDK_ROOT="$NDK_ROOT"
        export PATH="$TOOLCHAIN_DIR/bin:$PATH"
        make clean >/dev/null 2>&1 || true
        export CFLAGS="-fPIC ${CFLAGS:-}"
        export CXXFLAGS="-fPIC ${CXXFLAGS:-}"
        ./Configure "$OPENSSL_TARGET" -D__ANDROID_API__="$ANDROID_API" \
            --prefix="$OPENSSL_OUT_DIR" \
            no-shared no-tests no-module no-asm
        make -j"$(cpu_count)"
        make install_sw
    )
}

write_boost_user_config() {
    local config_file=$1
    local clangxx="$TOOLCHAIN_DIR/bin/${CLANG_TRIPLE}${ANDROID_API}-clang++"

    {
        printf 'using clang : %s : %s :\n' "$BOOST_TOOLSET_SUFFIX" "$clangxx"
        printf '    <archiver>%s/bin/llvm-ar\n' "$TOOLCHAIN_DIR"
        printf '    <ranlib>%s/bin/llvm-ranlib\n' "$TOOLCHAIN_DIR"
        printf '    <compileflags>--target=%s%s\n' "$CLANG_TRIPLE" "$ANDROID_API"
        printf '    <compileflags>--sysroot=%s/sysroot\n' "$TOOLCHAIN_DIR"
        printf '    <compileflags>-fPIC\n'
        printf '    <compileflags>-std=c++17\n'
        printf '    <compileflags>-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION\n'
        printf '    <linkflags>--target=%s%s\n' "$CLANG_TRIPLE" "$ANDROID_API"
        printf '    <linkflags>--sysroot=%s/sysroot\n' "$TOOLCHAIN_DIR"
        printf ';\n'
    } > "$config_file"
}

build_boost() {
    local required_libs=(system coroutine thread context regex filesystem)
    local missing=false
    for lib in "${required_libs[@]}"; do
        if [ ! -f "$BOOST_OUT_DIR/libboost_$lib.a" ]; then
            missing=true
            break
        fi
    done

    if [ "$missing" = false ] && boost_context_has_fcontext; then
        echo "Boost 已存在: $BOOST_OUT_DIR"
        return
    fi

    if [ "$missing" = false ]; then
        echo "Boost.Context 缺少 fcontext 符号，重新编译: $BOOST_OUT_DIR"
    fi

    ensure_boost_source

    echo "编译 Boost: $ANDROID_ABI_NAME"
    rm -rf "$BOOST_OUT_DIR"
    mkdir -p "$BOOST_OUT_DIR"

    local user_config
    user_config="$(mktemp "$PROJECT_ROOT/build-boost-user-config.XXXXXX")"
    write_boost_user_config "$user_config"

    (
        cd "$BOOST_SRC_DIR"
        if [ ! -x ./b2 ]; then
            ./bootstrap.sh --with-toolset=clang
        fi

        ./b2 -j"$(cpu_count)" \
            --user-config="$user_config" \
            --build-dir="$BOOST_OUT_DIR/build" \
            toolset=clang-"$BOOST_TOOLSET_SUFFIX" \
            target-os=android \
            binary-format=elf \
            architecture="$BOOST_ARCHITECTURE" \
            address-model="$BOOST_ADDRESS_MODEL" \
            abi="$BOOST_ABI" \
            context-impl=fcontext \
            link=static \
            threading=multi \
            runtime-link=static \
            variant=release \
            --with-system \
            --with-coroutine \
            --with-thread \
            --with-context \
            --with-regex \
            --with-filesystem \
            --stagedir="$BOOST_OUT_DIR/stage" \
            stage
    )

    rm -f "$user_config"
    find "$BOOST_OUT_DIR/stage/lib" -type f -name 'libboost_*.a' -exec cp {} "$BOOST_OUT_DIR/" \;

    for lib in "${required_libs[@]}"; do
        if [ ! -f "$BOOST_OUT_DIR/libboost_$lib.a" ]; then
            echo "错误: missing Boost library: $BOOST_OUT_DIR/libboost_$lib.a"
            exit 1
        fi
    done

    if ! boost_context_has_fcontext; then
        echo "错误: Boost.Context 缺少 make_fcontext/jump_fcontext/ontop_fcontext 符号"
        exit 1
    fi
}

build_abi() {
    normalize_abi "$1"
    check_tools
    build_openssl
    build_boost

    echo ""
    echo "=========================================="
    echo "编译架构: $ANDROID_ABI_NAME (PPP ABI: $PPP_ABI)"
    echo "=========================================="

    local build_dir="$PROJECT_ROOT/build/android-local/$NDK_REVISION/$ANDROID_ABI_NAME"
    local output_dir="$PROJECT_ROOT/bin/android/$ANDROID_ABI_NAME"
    rm -rf "$build_dir"
    mkdir -p "$build_dir" "$output_dir"

    cd "$build_dir"

    echo "运行 CMake..."
    "$ANDROID_CMAKE" "$PROJECT_ROOT/android" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
        -DCMAKE_SYSTEM_NAME=Android \
        -DANDROID_ABI="$ANDROID_ABI_NAME" \
        -DANDROID_NATIVE_API_LEVEL="$ANDROID_API" \
        -DANDROID_STL=c++_static \
        -DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$output_dir" \
        -DTHIRD_PARTY_LIBRARY_DIR="$THIRD_PARTY_DIR" \
        -DBOOST_ANDROID_INCLUDE_DIR="$BOOST_SRC_DIR" \
        -DBOOST_ANDROID_LIB_DIR="$BOOST_OUT_DIR" \
        -DOPENSSL_ANDROID_ROOT="$OPENSSL_OUT_DIR"

    echo "开始编译..."
    make -j"$(cpu_count)"

    if [ -f "$output_dir/libopenppp2.so" ]; then
        echo ""
        echo "编译成功!"
        echo "产物路径: $output_dir/libopenppp2.so"
        echo "文件大小: $(ls -lh "$output_dir/libopenppp2.so" | awk '{print $5}')"
    else
        echo "错误: 编译失败，找不到产物文件"
        exit 1
    fi

    cd "$PROJECT_ROOT"
    rm -rf "$build_dir"
}

clean_build() {
    echo "清理构建目录..."
    rm -rf "$PROJECT_ROOT/android/build"
    rm -rf "$PROJECT_ROOT/bin/android"
    rm -rf "$PROJECT_ROOT/build/android-local"
    echo "清理完成"
}

# ============================================================================
# 主程序
# ============================================================================

ACTION="${1:-arm64}"
ACTION="$(printf '%s' "$ACTION" | tr '[:upper:]' '[:lower:]')"

case "$ACTION" in
    help|-h|--help)
        print_help
        exit 0
        ;;
    clean)
        clean_build
        exit 0
        ;;
    arm64|arm|x86|x64)
        build_abi "$ACTION"
        ;;
    all)
        build_abi arm
        build_abi x86
        build_abi x64
        build_abi arm64
        ;;
    *)
        echo "错误: 未知选项 '$ACTION'"
        echo ""
        print_help
        exit 1
        ;;
esac

echo ""
echo "构建完成!"
