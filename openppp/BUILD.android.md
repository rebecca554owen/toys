---
name: openppp-build-android
description: 在 macOS 上本地编译并打包 openppp2 APK，以及 GitHub Actions 构建说明。
---

# 在 macOS 上编译并打包 openppp2 APK

已验证环境：macOS 14 (Apple Silicon)

## 1. 环境要求

- Flutter 3.44（stable，路径 `~/flutter`）
- Android Studio（自带 JDK 21 和 SDK 管理）
- Android SDK：`platform-tools`、`platforms;android-36`、`build-tools;36.0.0`
- Android NDK 29.0.14206865（Gradle 自动发现，无需 `ndk.dir`）
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
| Boost | 1.87.0 | `third-party/boost/arm64-v8a/` | Android arm64 静态库（`.a`），从 archives.boost.io 下载源码编译 |
| OpenSSL | 4.0.0 | `third-party/openssl-arm64/` | Android 构建专用，`no-shared no-tests no-module`，从 GitHub release 下载源码编译 |

Android 构建实际链接的产物：

- `third-party/boost/arm64-v8a/libboost_*.a`
- `third-party/openssl-arm64/lib/libssl.a` + `libcrypto.a`
- `third-party/openssl-arm64/include/openssl/`

> `.gitignore` 已忽略 `/third-party`，该生成目录不会被 git 跟踪。

## 4. 本地依赖准备

`build-android-local.sh` 会自动从源码下载并编译 Boost 和 OpenSSL，无需手动 clone。

本地脚本默认路径：
- Boost 源码缓存：`third-party/boost-src/`
- OpenSSL 源码缓存：`third-party/openssl-src/`
- 产物：`third-party/boost/arm64-v8a/` 和 `third-party/openssl-arm64/`

直接运行：

```bash
cd ~/Documents/GitHub/toys/openppp
./build-android-local.sh arm64
```

如需调整版本或路径，通过环境变量：

```bash
NDK_ROOT=~/Library/Android/sdk/ndk/29.0.14206865 \
THIRD_PARTY_DIR=~/Documents/GitHub/openppp2/third-party \
BOOST_VERSION=1.87.0 \
OPENSSL_VERSION=4.0.0 \
./build-android-local.sh arm64
```

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

## 6. 生成 `libopenppp2.so`（arm64-v8a）

前提：`third-party/boost/arm64-v8a/` 和 `third-party/openssl-arm64/` 已准备好；如果不存在，本地脚本会自动生成。

本地快速构建脚本：`toys/openppp/build-android-local.sh`

```bash
cd ~/Documents/GitHub/toys/openppp
./build-android-local.sh arm64
```

产物路径：`~/Documents/GitHub/openppp2/android/build/libopenppp2.so`

CMake 配置参数（关键）：
- `-DTHIRD_PARTY_LIBRARY_DIR=~/Documents/GitHub/openppp2/third-party`
- `-DBOOST_ANDROID_INCLUDE_DIR`、`-DBOOST_ANDROID_LIB_DIR`、`-DOPENSSL_ANDROID_ROOT` 指向生成的 Android 依赖

## 7. 编译 APK

```bash
cd ~/Documents/GitHub/openppp2/android
~/flutter/bin/flutter pub get
~/flutter/bin/flutter build apk --release
```

产物路径：
```
openppp2/android/build/app/outputs/flutter-apk/app-release.apk
```

APK 内包含：
- `lib/arm64-v8a/libopenppp2.so`（本地编译，~19 MB 未压缩）
- `lib/arm64-v8a/libflutter.so`

## 8. Clean Build 耗时参考

完整重编（含 CMake 配置 + C++ 编译/链接 + APK 打包）约 **7~8 秒**：

```bash
cd ~/Documents/GitHub/openppp2/android/android
./gradlew clean
cd ..
~/flutter/bin/flutter build apk --release
```

## 9. 其他 ABI（可选）

若需 armeabi-v7a / x86 / x86_64，可从 `openppp2-android` 复制 `.so` 到对应 `jniLibs/` 目录，但 arm64-v8a 必须本地编译。

```bash
OPENPPP2=~/Documents/GitHub/openppp2
OPENPPP2_ANDROID=~/Documents/GitHub/openppp2-android

for abi in armeabi-v7a x86 x86_64; do
  mkdir -p "$OPENPPP2/android/android/app/src/main/jniLibs/$abi"
  cp "$OPENPPP2_ANDROID/app/libs/$abi/libopenppp2.so" \
     "$OPENPPP2/android/android/app/src/main/jniLibs/$abi/"
done
```

## 10. 关键说明

- **构建目录：** 用 `build-android/`（`flutter build` 默认），与 macOS 的 `build-macos/` 分开。
- **构建目标：** `openppp2`（不是 `ppp`）。
- **OpenSSL 目录：** Android 使用 `third-party/openssl-arm64/`，不要覆盖 macOS 的 OpenSSL 目录。
- **jemalloc：** Android 构建不需要（CMakeLists.txt 只在 Windows 分支检查 jemalloc）。
- **NDK 版本：** CI 使用 r29（`android-ndk-r29-linux.zip`）；本地建议使用 29.0.14206865。
