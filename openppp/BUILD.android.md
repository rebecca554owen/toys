---
name: openppp-build-android
description: 在 macOS 上本地编译并打包 openppp2 APK，以及 GitHub Actions 构建说明。
---

# 在 macOS 上编译并打包 openppp2 APK

已验证环境：macOS 14 (Apple Silicon)

## 1. 环境要求

- Flutter 3.44（stable，brew 管理：`/opt/homebrew/bin/flutter`）
- Android Studio（自带 JDK 21 和 SDK 管理）
- Android SDK：`platform-tools`、`platforms;android-36`、`build-tools;36.0.0`
- Android NDK 29.0.14206865（推荐；性能和 CI/release 对齐；Gradle 自动发现，无需 `ndk.dir`）
- Ninja（`brew install ninja`）

## 2. 源码仓库位置

默认根目录：`~/Documents/GitHub/`

- `openppp2` — 主仓库（C++ 源码 + Flutter Android 工程 + CMake）
- `toys` — 构建脚本和 CI workflow（`toys/openppp/`）
- `key` — 签名材料（`app.key` + `key.properties`）

> 假定仓库已就位。

## 3. 第三方依赖（third-party）

Android 依赖不是仓库自带，全部需从源码下载并编译生成。Android 和 macOS 共用 `openppp2/third-party/` 根目录，但 Android 静态库必须放在 ABI/平台子目录里，避免覆盖 macOS 产物。

| 库 | 版本 | 目录 | 说明 |
|---|---|---|---|
| Boost | 1.86.0 | `third-party/boost/arm64-v8a/` | Android arm64 静态库（`.a`），从 archives.boost.io 下载源码编译 |
| OpenSSL | 4.0.0 | `third-party/openssl-arm64/` | Android 构建专用，`no-shared no-tests no-module`，从 GitHub release 下载源码编译 |

Android 构建实际链接的产物：

- `third-party/boost/arm64-v8a/libboost_*.a`
- `third-party/openssl-arm64/lib/libssl.a` + `libcrypto.a`
- `third-party/openssl-arm64/include/openssl/`

> `.gitignore` 已忽略 `/third-party`，该生成目录不会被 git 跟踪。

## 4. 本地依赖准备

Android 依赖（Boost / OpenSSL）已预编译到 `openppp2/third-party/`，四个 ABI 齐全：

| ABI | Boost | OpenSSL |
|---|---|---|
| arm64-v8a | `boost/arm64-v8a/libboost_*.a` | `openssl-arm64/` |
| armeabi-v7a | `boost/armeabi-v7a/libboost_*.a` | `openssl-armeabi-v7a/` |
| x86 | `boost/x86/libboost_*.a` | `openssl-x86/` |
| x86_64 | `boost/x86_64/libboost_*.a` | `openssl-x86_64/` |

源码缓存：`third-party/boost-src/` 和 `third-party/openssl-src/`。

如需重新编译某个 ABI 的 Boost，参考 `toys` 仓库 CI workflow 中的 Build Boost 步骤。

## 5. 签名材料

签名材料统一维护在 `key` 仓库，`openppp2` 只保留软链。

```bash
KEY=~/Documents/GitHub/key
OPENPPP2=~/Documents/GitHub/openppp2

# Gradle 的 rootProject 是 openppp2/android/android
mkdir -p "$OPENPPP2/android/android/keystore"
ln -sf "$KEY/app.key"       "$OPENPPP2/android/android/keystore/yav-release-key.p12"
ln -sf "$KEY/key.properties" "$OPENPPP2/android/android/keystore/yav-release-key.properties"

# key.properties 内容（与 Actions 一致）：
# storeFile=keystore/yav-release-key.p12
# storePassword=...
# keyAlias=...
# keyPassword=...
```

## 6. 生成 `libopenppp2.so`

前提：`openppp2/third-party/` 已具备对应 ABI 的 Boost / OpenSSL 产物。

推荐直接在 `openppp2` 仓库里运行本地脚本：

```bash
cd ~/Documents/GitHub/openppp2
NDK_ROOT=~/Library/Android/sdk/ndk/29.0.14206865 \
THIRD_PARTY_DIR=~/Documents/GitHub/openppp2/third-party \
bash ./build-android-local.sh arm64
```

若要一次生成 4 个 ABI：

```bash
cd ~/Documents/GitHub/openppp2
NDK_ROOT=~/Library/Android/sdk/ndk/29.0.14206865 \
THIRD_PARTY_DIR=~/Documents/GitHub/openppp2/third-party \
bash ./build-android-local.sh all
```

arm64 产物路径：`~/Documents/GitHub/openppp2/bin/android/arm64-v8a/libopenppp2.so`

4 ABI 产物路径：
- `bin/android/arm64-v8a/libopenppp2.so`
- `bin/android/armeabi-v7a/libopenppp2.so`
- `bin/android/x86/libopenppp2.so`
- `bin/android/x86_64/libopenppp2.so`

CMake 配置参数（关键）：
- `-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION`
- `-DTHIRD_PARTY_LIBRARY_DIR=~/Documents/GitHub/openppp2/third-party`
- `-DBOOST_ANDROID_INCLUDE_DIR`、`-DBOOST_ANDROID_LIB_DIR`、`-DOPENSSL_ANDROID_ROOT` 指向生成的 Android 依赖

## 7. 编译 APK

将 4 个 ABI 的 `.so` 复制到 `jniLibs` 后，用 Flutter 打包：

```bash
OPENPPP2=~/Documents/GitHub/openppp2

# 复制 .so 到 jniLibs
for abi in arm64-v8a armeabi-v7a x86 x86_64; do
  mkdir -p "$OPENPPP2/android/android/app/src/main/jniLibs/$abi"
  cp "$OPENPPP2/bin/android/$abi/libopenppp2.so" \
     "$OPENPPP2/android/android/app/src/main/jniLibs/$abi/"
done

# 打包
cd "$OPENPPP2/android"
/opt/homebrew/bin/flutter pub get
/opt/homebrew/bin/flutter build apk --release
```

产物路径：
```
openppp2/android/build/app/outputs/flutter-apk/app-release.apk
```

APK 内包含：
- `lib/arm64-v8a/libopenppp2.so`（本地编译，~24 MB 未压缩）
- `lib/armeabi-v7a/libopenppp2.so`
- `lib/x86/libopenppp2.so`
- `lib/x86_64/libopenppp2.so`
- `lib/<abi>/libflutter.so`

## 8. Native `.so` NDK 选择和耗时参考

本地 Apple Silicon 对 `arm64-v8a` 做过一次干净 native `.so` 编译对比（含 CMake 配置、C++ 编译和链接，不含 Boost/OpenSSL 从源码重建）：

| NDK | 结果 | 耗时 | `libopenppp2.so` 大小 | 建议 |
| --- | --- | ---: | ---: | --- |
| `26.1.10909125` | 成功 | 5 分 04 秒 | 24.4 MB | 可用于本地快速验证 |
| `29.0.14206865` | 成功 | 7 分 16 秒 | 28.8 MB | 推荐使用；性能表现和 CI/release 对齐 |

结论：推荐使用 NDK r29，和 GitHub Actions Android workflow 保持一致；NDK r26 可作为本地快速验证备选。

## 9. APK Clean Build 耗时参考

完整 APK 重编（Flutter/Gradle 打包，使用已生成的 `jniLibs`）约 **20 秒**：

```bash
cd ~/Documents/GitHub/openppp2/android/android
./gradlew clean
cd ..
/opt/homebrew/bin/flutter build apk --release
```

## 10. 关键说明

- **构建目录：** `.so` 产物在 `bin/android/<abi>/`，APK 产物在 `android/build/`，与 macOS 的 `build-macos/` 分开。
- **构建目标：** `openppp2`（不是 `ppp`）。
- **OpenSSL 目录：** Android 使用 `third-party/openssl-<abi>/`，不要覆盖 macOS 的 OpenSSL 目录。
- **jemalloc：** Android 构建不需要（CMakeLists.txt 只在 Windows 分支检查 jemalloc）。
- **NDK 版本：** 推荐使用 r29（`29.0.14206865`），和 CI/release 保持一致；r26 可作为本地快速验证备选。
- **C++ 标准：** Android CMake 使用 C++17，并为 Boost 1.86.0 添加 `_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION`。
- **Flutter：** brew 管理（`brew install --cask flutter`），当前稳定版 3.44.5。
