#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

SCRIPT_DIR = Path(__file__).resolve().parent
HOME = Path.home()


@dataclass(frozen=True)
class AbiConfig:
    action: str
    ppp_abi: str
    android_abi: str
    openssl_target: str
    clang_triple: str
    boost_toolset_suffix: str
    boost_architecture: str
    boost_address_model: str
    boost_abi: str
    openssl_dir_name: str


ABI_CONFIGS = {
    "arm64": AbiConfig("arm64", "aarch64", "arm64-v8a", "android-arm64", "aarch64-linux-android", "androidarm64", "arm", "64", "aapcs", "openssl-arm64"),
    "arm": AbiConfig("arm", "armv7a", "armeabi-v7a", "android-arm", "armv7a-linux-androideabi", "androidarm", "arm", "32", "aapcs", "openssl-armeabi-v7a"),
    "x86": AbiConfig("x86", "x86", "x86", "android-x86", "i686-linux-android", "androidx86", "x86", "32", "sysv", "openssl-x86"),
    "x64": AbiConfig("x64", "x64", "x86_64", "android-x86_64", "x86_64-linux-android", "androidx64", "x86", "64", "sysv", "openssl-x86_64"),
}


class BuildError(RuntimeError):
    def __init__(self, message: str, log: Path | None = None):
        super().__init__(message)
        self.log = log


class Builder:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.project_root = SCRIPT_DIR
        self.repo_root = Path(args.repo_root).expanduser().resolve()
        self.openppp2_root = self.resolve_openppp2_root(args)
        self.ndk_root = Path(os.environ.get("NDK_ROOT", args.ndk_root)).expanduser().resolve()
        self.third_party_dir = self.resolve_third_party_dir(args)
        self.android_cmake = Path(os.environ.get("ANDROID_CMAKE", args.android_cmake)).expanduser().resolve()
        self.android_api = os.environ.get("ANDROID_API", args.android_api)
        self.boost_version = os.environ.get("BOOST_VERSION", args.boost_version)
        self.openssl_version = os.environ.get("OPENSSL_VERSION", args.openssl_version)
        self.boost_src_dir = Path(os.environ.get("BOOST_SRC_DIR", str(self.third_party_dir / "boost-src"))).expanduser().resolve()
        self.openssl_src_dir = Path(os.environ.get("OPENSSL_SRC_DIR", str(self.third_party_dir / "openssl-src"))).expanduser().resolve()
        self.jobs = int(os.environ.get("BUILD_JOBS", args.jobs or str(os.cpu_count() or 4)))
        self.toolchain_dir = self.detect_toolchain_dir()
        self.ndk_revision = self.read_ndk_revision()
        self.build_id = self.make_build_id(args)
        self.log_dir = Path(args.log_dir).expanduser().resolve() / self.build_id
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def resolve_openppp2_root(self, args: argparse.Namespace) -> Path:
        explicit_root = os.environ.get("OPENPPP2_ROOT") or args.openppp2_root
        if args.branch:
            if explicit_root:
                raise BuildError("--branch 不能和 --openppp2-root / OPENPPP2_ROOT 同时使用")
            return self.prepare_branch_worktree(args.branch, self.repo_root, Path(args.worktree_base).expanduser().resolve(), args.fetch)
        if explicit_root:
            return Path(explicit_root).expanduser().resolve()
        return self.repo_root

    def resolve_third_party_dir(self, args: argparse.Namespace) -> Path:
        explicit_dir = os.environ.get("THIRD_PARTY_DIR") or args.third_party_dir
        if explicit_dir:
            return Path(explicit_dir).expanduser().resolve()
        if args.isolated_third_party or not args.branch:
            return self.openppp2_root / "third-party"
        return self.link_shared_third_party(self.repo_root / "third-party")

    def link_shared_third_party(self, shared_dir: Path) -> Path:
        target = self.openppp2_root / "third-party"
        shared_dir.mkdir(parents=True, exist_ok=True)
        if target.is_symlink():
            if target.resolve() != shared_dir.resolve():
                target.unlink()
                target.symlink_to(shared_dir, target_is_directory=True)
            return target
        if target.exists():
            return target
        target.symlink_to(shared_dir, target_is_directory=True)
        return target

    def git(self, repo: Path, command: list[str], capture: bool = False) -> str:
        result = subprocess.run(["git", "-C", str(repo), *command], text=True, stdout=subprocess.PIPE if capture else None, stderr=subprocess.PIPE if capture else None)
        if result.returncode != 0:
            detail = result.stderr.strip() if capture and result.stderr else " ".join(command)
            raise BuildError(f"git 命令失败: {detail}")
        return result.stdout.strip() if capture and result.stdout else ""

    def prepare_branch_worktree(self, branch: str, repo_root: Path, worktree_base: Path, fetch: bool) -> Path:
        if not (repo_root / ".git").exists():
            raise BuildError(f"找不到 openppp2 git 仓库: {repo_root}")
        if fetch:
            self.git(repo_root, ["fetch", "origin", branch, "--prune"])
        safe_branch = re.sub(r"[^A-Za-z0-9._-]+", "-", branch).strip("-")
        worktree = worktree_base / f"openppp2-validate-{safe_branch}"
        ref = f"origin/{branch}"
        if worktree.exists():
            if not (worktree / ".git").exists():
                raise BuildError(f"worktree 路径已存在但不是 git worktree: {worktree}")
            self.git(worktree, ["checkout", "--detach", ref])
        else:
            worktree.parent.mkdir(parents=True, exist_ok=True)
            self.git(repo_root, ["worktree", "add", "--detach", str(worktree), ref])
        commit = self.git(worktree, ["rev-parse", "--short", "HEAD"], capture=True)
        print(f"使用 openppp2 {branch}: {worktree} @ {commit}", flush=True)
        return worktree.resolve()

    def detect_toolchain_dir(self) -> Path:
        x86_dir = self.ndk_root / "toolchains/llvm/prebuilt/darwin-x86_64"
        arm_dir = self.ndk_root / "toolchains/llvm/prebuilt/darwin-arm64"
        return x86_dir if x86_dir.exists() else arm_dir

    def read_ndk_revision(self) -> str:
        source_properties = self.ndk_root / "source.properties"
        if not source_properties.exists():
            return "unknown"
        for line in source_properties.read_text(errors="ignore").splitlines():
            if line.startswith("Pkg.Revision = "):
                return re.sub(r"[^A-Za-z0-9._-]+", "_", line.split("=", 1)[1].strip())
        return "unknown"

    def make_build_id(self, args: argparse.Namespace) -> str:
        label = args.branch or self.openppp2_root.name
        try:
            commit = self.git(self.openppp2_root, ["rev-parse", "--short", "HEAD"], capture=True)
        except BuildError:
            commit = "nogit"
        return re.sub(r"[^A-Za-z0-9._-]+", "-", f"{label}-{commit}").strip("-") or "local"

    def info(self, message: str) -> None:
        print(message, flush=True)

    def check_tools(self) -> None:
        self.info("检查工具链...")
        self.info(f"源码目录: {self.openppp2_root}")
        self.info(f"third-party: {self.third_party_dir}")
        self.info(f"构建 ID: {self.build_id}")
        self.info(f"日志目录: {self.log_dir}")
        required_paths = [
            (self.openppp2_root / "android/CMakeLists.txt", "openppp2 Android CMakeLists.txt"),
            (self.ndk_root, "NDK 目录"),
            (self.ndk_root / "build/cmake/android.toolchain.cmake", "NDK CMake toolchain"),
            (self.toolchain_dir / "bin", "NDK LLVM toolchain"),
            (self.android_cmake, "Android SDK CMake"),
        ]
        for path, label in required_paths:
            if not path.exists():
                raise BuildError(f"找不到 {label}: {path}")
        for tool in ("curl", "make", "perl", "tar"):
            if shutil.which(tool) is None:
                raise BuildError(f"缺少工具: {tool}")
        self.info("工具链检查通过")

    def run(self, title: str, command: list[str], cwd: Path | None = None, env: dict[str, str] | None = None, log_name: str | None = None) -> None:
        log = self.log_dir / (log_name or f"{re.sub(r'[^A-Za-z0-9._-]+', '-', title).strip('-')}.log")
        self.info(f"\n▶ {title}")
        self.info(f"  cwd: {cwd or Path.cwd()}")
        self.info(f"  log: {log}")
        started = time.monotonic()
        with log.open("w", encoding="utf-8", errors="replace") as log_file:
            log_file.write("$ " + " ".join(command) + "\n")
            process = subprocess.Popen(command, cwd=str(cwd) if cwd else None, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
            last_percent = -1
            recent: list[str] = []
            assert process.stdout is not None
            for line in process.stdout:
                log_file.write(line)
                log_file.flush()
                stripped = line.rstrip()
                if stripped:
                    recent.append(stripped)
                    recent = recent[-30:]
                percent = self.extract_percent(stripped)
                if percent is not None and percent != last_percent:
                    print(f"\r  progress: {percent:3d}%", end="", flush=True)
                    last_percent = percent
                elif self.args.verbose and stripped:
                    print("  " + stripped, flush=True)
            rc = process.wait()
            if last_percent >= 0:
                print(flush=True)
            elapsed = self.format_duration(time.monotonic() - started)
            if rc != 0:
                self.info(f"✗ {title} 失败，耗时 {elapsed}")
                self.print_failure_summary(recent)
                raise BuildError(f"{title} 失败，退出码 {rc}", log)
            self.info(f"✓ {title} 完成，耗时 {elapsed}")

    @staticmethod
    def extract_percent(line: str) -> int | None:
        match = re.search(r"\[\s*(\d{1,3})%\]", line)
        if match:
            return max(0, min(100, int(match.group(1))))
        match = re.search(r"\[\s*(\d+)\s*/\s*(\d+)\s*\]", line)
        if not match:
            return None
        current, total = int(match.group(1)), int(match.group(2))
        return max(0, min(100, int(current * 100 / total))) if total > 0 else None

    @staticmethod
    def format_duration(seconds: float) -> str:
        total = int(round(seconds))
        minutes, secs = divmod(total, 60)
        return f"{minutes} 分 {secs:02d} 秒" if minutes else f"{secs} 秒"

    @staticmethod
    def format_size(path: Path) -> str:
        return f"{path.stat().st_size / 1024 / 1024:.1f} MB"

    def print_failure_summary(self, lines: Iterable[str]) -> None:
        patterns = ("error:", "undefined reference", "No such file", "找不到", "错误", "FAILED", "CMake Error")
        hits = [line for line in lines if any(pattern in line for pattern in patterns)]
        self.info("失败关键日志:" if hits else "失败前最后日志:")
        for line in (hits or list(lines))[-12:]:
            self.info("  " + line)

    def download(self, url: str, dest: Path) -> None:
        dest.parent.mkdir(parents=True, exist_ok=True)
        self.info(f"下载: {url}")
        with urllib.request.urlopen(url) as response, dest.open("wb") as output:
            total = int(response.headers.get("Content-Length") or 0)
            downloaded = 0
            last = -1
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
                downloaded += len(chunk)
                if total:
                    percent = int(downloaded * 100 / total)
                    if percent != last:
                        print(f"\r  download: {percent:3d}%", end="", flush=True)
                        last = percent
            if total:
                print(flush=True)

    def ensure_boost_source(self) -> None:
        expected = self.boost_version.replace(".", "_")
        version_file = self.boost_src_dir / "boost/version.hpp"
        if version_file.exists() and f'BOOST_LIB_VERSION "{expected}"' in version_file.read_text(errors="ignore"):
            return
        archive = self.third_party_dir / f"boost_{expected}.tar.bz2"
        extract_dir = self.third_party_dir / f"boost_{expected}"
        self.info(f"准备 Boost {self.boost_version} 源码...")
        if not archive.exists():
            self.download(f"https://archives.boost.io/release/{self.boost_version}/source/boost_{expected}.tar.bz2", archive)
        shutil.rmtree(extract_dir, ignore_errors=True)
        shutil.rmtree(self.boost_src_dir, ignore_errors=True)
        self.info("解压 Boost...")
        with tarfile.open(archive, "r:bz2") as tar:
            tar.extractall(self.third_party_dir)
        extract_dir.rename(self.boost_src_dir)

    def ensure_openssl_source(self) -> None:
        if (self.openssl_src_dir / "Configure").exists():
            return
        archive = self.third_party_dir / f"openssl-{self.openssl_version}.tar.gz"
        extract_dir = self.third_party_dir / f"openssl-{self.openssl_version}"
        self.info(f"准备 OpenSSL {self.openssl_version} 源码...")
        if not archive.exists():
            self.download(f"https://github.com/openssl/openssl/releases/download/openssl-{self.openssl_version}/openssl-{self.openssl_version}.tar.gz", archive)
        shutil.rmtree(extract_dir, ignore_errors=True)
        shutil.rmtree(self.openssl_src_dir, ignore_errors=True)
        self.info("解压 OpenSSL...")
        with tarfile.open(archive, "r:gz") as tar:
            tar.extractall(self.third_party_dir)
        extract_dir.rename(self.openssl_src_dir)

    def boost_context_has_fcontext(self, boost_out_dir: Path) -> bool:
        context_lib = boost_out_dir / "libboost_context.a"
        nm = self.toolchain_dir / "bin/llvm-nm"
        if not context_lib.exists() or not nm.exists():
            return False
        result = subprocess.run([str(nm), "-g", str(context_lib)], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        return all(re.search(rf" ({symbol})$", result.stdout, re.MULTILINE) for symbol in ("make_fcontext", "jump_fcontext", "ontop_fcontext"))

    def build_openssl(self, abi: AbiConfig, openssl_out_dir: Path) -> None:
        if (openssl_out_dir / "lib/libssl.a").exists() and (openssl_out_dir / "lib/libcrypto.a").exists():
            self.info(f"OpenSSL 已存在: {openssl_out_dir}")
            return
        self.ensure_openssl_source()
        shutil.rmtree(openssl_out_dir, ignore_errors=True)
        openssl_out_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env.update({
            "ANDROID_NDK_HOME": str(self.ndk_root),
            "ANDROID_NDK_ROOT": str(self.ndk_root),
            "PATH": f"{self.toolchain_dir / 'bin'}:{env.get('PATH', '')}",
            "CFLAGS": f"-fPIC {env.get('CFLAGS', '')}".strip(),
            "CXXFLAGS": f"-fPIC {env.get('CXXFLAGS', '')}".strip(),
        })
        if (self.openssl_src_dir / "Makefile").exists():
            self.run(f"OpenSSL clean {abi.android_abi}", ["make", "clean"], cwd=self.openssl_src_dir, env=env, log_name=f"openssl-{abi.android_abi}-clean.log")
        self.run(f"OpenSSL configure {abi.android_abi}", ["./Configure", abi.openssl_target, f"-D__ANDROID_API__={self.android_api}", f"--prefix={openssl_out_dir}", "no-shared", "no-tests", "no-module", "no-asm"], cwd=self.openssl_src_dir, env=env, log_name=f"openssl-{abi.android_abi}-configure.log")
        self.run(f"OpenSSL build {abi.android_abi}", ["make", f"-j{self.jobs}"], cwd=self.openssl_src_dir, env=env, log_name=f"openssl-{abi.android_abi}-build.log")
        self.run(f"OpenSSL install {abi.android_abi}", ["make", "install_sw"], cwd=self.openssl_src_dir, env=env, log_name=f"openssl-{abi.android_abi}-install.log")

    def write_boost_user_config(self, abi: AbiConfig, path: Path) -> None:
        clangxx = self.toolchain_dir / "bin" / f"{abi.clang_triple}{self.android_api}-clang++"
        path.write_text(
            f"using clang : {abi.boost_toolset_suffix} : {clangxx} :\n"
            f"    <archiver>{self.toolchain_dir}/bin/llvm-ar\n"
            f"    <ranlib>{self.toolchain_dir}/bin/llvm-ranlib\n"
            f"    <compileflags>--target={abi.clang_triple}{self.android_api}\n"
            f"    <compileflags>--sysroot={self.toolchain_dir}/sysroot\n"
            f"    <compileflags>-fPIC\n"
            f"    <compileflags>-std=c++17\n"
            f"    <compileflags>-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION\n"
            f"    <linkflags>--target={abi.clang_triple}{self.android_api}\n"
            f"    <linkflags>--sysroot={self.toolchain_dir}/sysroot\n"
            f";\n"
        )

    def build_boost(self, abi: AbiConfig, boost_out_dir: Path) -> None:
        required = ["system", "coroutine", "thread", "context", "regex", "filesystem"]
        libs_ok = all((boost_out_dir / f"libboost_{lib}.a").exists() for lib in required)
        if libs_ok and self.boost_context_has_fcontext(boost_out_dir):
            self.info(f"Boost 已存在: {boost_out_dir}")
            return
        self.ensure_boost_source()
        shutil.rmtree(boost_out_dir, ignore_errors=True)
        boost_out_dir.mkdir(parents=True, exist_ok=True)
        user_config = self.project_root / f"build-boost-user-config-{abi.android_abi}.jam"
        self.write_boost_user_config(abi, user_config)
        try:
            if not (self.boost_src_dir / "b2").exists():
                self.run("Boost bootstrap", ["./bootstrap.sh", "--with-toolset=clang"], cwd=self.boost_src_dir, log_name="boost-bootstrap.log")
            command = [
                "./b2", f"-j{self.jobs}", f"--user-config={user_config}", f"--build-dir={boost_out_dir / 'build'}",
                f"toolset=clang-{abi.boost_toolset_suffix}", "target-os=android", "binary-format=elf",
                f"architecture={abi.boost_architecture}", f"address-model={abi.boost_address_model}", f"abi={abi.boost_abi}",
                "context-impl=fcontext", "link=static", "threading=multi", "runtime-link=static", "variant=release",
                "--with-system", "--with-coroutine", "--with-thread", "--with-context", "--with-regex", "--with-filesystem",
                f"--stagedir={boost_out_dir / 'stage'}", "stage",
            ]
            self.run(f"Boost build {abi.android_abi}", command, cwd=self.boost_src_dir, log_name=f"boost-{abi.android_abi}-build.log")
        finally:
            user_config.unlink(missing_ok=True)
        for lib in (boost_out_dir / "stage/lib").glob("libboost_*.a"):
            shutil.copy2(lib, boost_out_dir / lib.name)
        missing = [lib for lib in required if not (boost_out_dir / f"libboost_{lib}.a").exists()]
        if missing:
            raise BuildError(f"Boost 缺少库: {', '.join(missing)}")
        if not self.boost_context_has_fcontext(boost_out_dir):
            raise BuildError("Boost.Context 缺少 make_fcontext/jump_fcontext/ontop_fcontext 符号")

    def prepare_legacy_layout(self, abi: AbiConfig, openssl_out_dir: Path) -> None:
        legacy_boost_header = self.third_party_dir / "boost" / "boost"
        if not legacy_boost_header.exists():
            legacy_boost_header.parent.mkdir(parents=True, exist_ok=True)
            legacy_boost_header.symlink_to(self.boost_src_dir / "boost", target_is_directory=True)
        legacy_openssl = self.third_party_dir / "openssl" / abi.android_abi
        legacy_openssl.parent.mkdir(parents=True, exist_ok=True)
        if legacy_openssl.exists() or legacy_openssl.is_symlink():
            if legacy_openssl.is_symlink() or legacy_openssl.is_file():
                legacy_openssl.unlink()
        if not legacy_openssl.exists():
            legacy_openssl.symlink_to(openssl_out_dir, target_is_directory=True)

    def build_abi(self, abi: AbiConfig) -> None:
        self.check_tools()
        boost_out_dir = self.third_party_dir / "boost" / abi.android_abi
        openssl_out_dir = self.third_party_dir / abi.openssl_dir_name
        self.build_openssl(abi, openssl_out_dir)
        self.build_boost(abi, boost_out_dir)
        self.prepare_legacy_layout(abi, openssl_out_dir)
        self.info(f"\n==========================================\n编译架构: {abi.android_abi} (PPP ABI: {abi.ppp_abi})\n==========================================")
        build_dir = self.project_root / "build/android-local" / self.build_id / abi.android_abi
        output_dir = self.openppp2_root / "bin/android" / abi.android_abi
        shutil.rmtree(build_dir, ignore_errors=True)
        build_dir.mkdir(parents=True, exist_ok=True)
        output_dir.mkdir(parents=True, exist_ok=True)
        cmake_command = [
            str(self.android_cmake), str(self.openppp2_root / "android"), "-DCMAKE_BUILD_TYPE=Release", "-G", "Ninja",
            f"-DCMAKE_TOOLCHAIN_FILE={self.ndk_root / 'build/cmake/android.toolchain.cmake'}", "-DCMAKE_SYSTEM_NAME=Android",
            f"-DANDROID_ABI={abi.android_abi}", f"-DANDROID_NATIVE_API_LEVEL={self.android_api}", "-DANDROID_STL=c++_static",
            f"-DCMAKE_LIBRARY_OUTPUT_DIRECTORY={output_dir}", f"-DTHIRD_PARTY_LIBRARY_DIR={self.third_party_dir}",
        ]
        started = time.monotonic()
        cmake_env = os.environ.copy()
        cmake_env["PPP_ANDROID_ABI"] = abi.android_abi
        self.run(f"CMake configure {abi.android_abi}", cmake_command, cwd=build_dir, env=cmake_env, log_name=f"cmake-{abi.android_abi}-configure.log")
        self.run(f"Ninja build {abi.android_abi}", ["ninja"], cwd=build_dir, env=cmake_env, log_name=f"ninja-{abi.android_abi}-build.log")
        so_path = output_dir / "libopenppp2.so"
        if not so_path.exists():
            raise BuildError(f"编译结束但找不到产物: {so_path}")
        self.info(f"✓ 编译成功: {so_path}")
        self.info(f"  文件大小: {self.format_size(so_path)}")
        self.info(f"  总耗时: {self.format_duration(time.monotonic() - started)}")
        if not self.args.keep_build:
            shutil.rmtree(build_dir, ignore_errors=True)

    def clean(self) -> None:
        self.info("清理构建目录...")
        shutil.rmtree(self.openppp2_root / "android/build", ignore_errors=True)
        shutil.rmtree(self.openppp2_root / "bin/android", ignore_errors=True)
        shutil.rmtree(self.project_root / "build/android-local", ignore_errors=True)
        self.info("清理完成")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="OpenPPP2 Android NDK 本地构建脚本")
    parser.add_argument("action", nargs="?", default="arm64", choices=["arm64", "arm", "x86", "x64", "all", "clean"], help="构建 ABI 或 all/clean")
    parser.add_argument("--branch", help="验证 origin/<branch>，自动创建/更新 /tmp/openppp2-validate-<branch> detached worktree")
    parser.add_argument("--repo-root", default=str(HOME / "Documents/GitHub/openppp2"), help="用于创建 worktree 和共享 third-party 缓存的 openppp2 主仓库路径")
    parser.add_argument("--worktree-base", default="/tmp", help="验证 worktree 根目录")
    parser.add_argument("--no-fetch", dest="fetch", action="store_false", help="使用 --branch 时不执行 git fetch")
    parser.add_argument("--openppp2-root", default=None, help="openppp2 仓库路径，也可用 OPENPPP2_ROOT")
    parser.add_argument("--ndk-root", default=str(HOME / "Library/Android/sdk/ndk/29.0.14206865"), help="NDK 路径，也可用 NDK_ROOT")
    parser.add_argument("--third-party-dir", default=None, help="third-party 路径，也可用 THIRD_PARTY_DIR")
    parser.add_argument("--isolated-third-party", action="store_true", help="使用当前 worktree 自己的 third-party；默认 --branch 会软链到 repo-root/third-party 共享缓存")
    parser.add_argument("--android-cmake", default=str(HOME / "Library/Android/sdk/cmake/3.22.1/bin/cmake"), help="Android SDK CMake 路径")
    parser.add_argument("--android-api", default="21", help="Android API level")
    parser.add_argument("--boost-version", default="1.86.0", help="Boost version")
    parser.add_argument("--openssl-version", default="4.0.0", help="OpenSSL version")
    parser.add_argument("--jobs", default=None, help="并行任务数，默认 CPU 数")
    parser.add_argument("--log-dir", default=str(SCRIPT_DIR / "build/logs/android-local"), help="日志根目录")
    parser.add_argument("--keep-build", action="store_true", help="保留 CMake build 目录")
    parser.add_argument("--verbose", action="store_true", help="输出完整子进程日志")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        builder = Builder(args)
        if args.action == "clean":
            builder.clean()
            return 0
        actions = ["arm", "x86", "x64", "arm64"] if args.action == "all" else [args.action]
        for action in actions:
            builder.build_abi(ABI_CONFIGS[action])
        builder.info("\n构建完成!")
        return 0
    except BuildError as error:
        print(f"\n错误: {error}", file=sys.stderr)
        if error.log:
            print(f"完整日志: {error.log}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n已中断", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
