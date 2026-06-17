#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AlbumPicker Release Build Script
构建AlbumPicker业务层并生成xcframework

依赖核心层 AlbumPickerCore 的构建产物（zip），
通过 vendored_frameworks 方式引入二进制，不依赖核心层源码。
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path
import argparse
import json
import zipfile
from datetime import datetime


class AlbumPickerBuilder:
    def __init__(self):
        # AlbumPicker 源码目录
        self.script_dir = Path(__file__).parent.absolute()
        self.output_dir = self.script_dir / "product"

        # 宿主工程路径
        self.app_dir = (
            self.script_dir.parent.parent.parent / "application"
        )
        self.workspace_path = self.app_dir / "App-UIKit.xcworkspace"
        self.podfile_path = self.app_dir / "Podfile"

        # 核心层产物路径（AlbumPickerCore 构建脚本的输出目录）
        self.core_product_dir = Path(
            os.environ.get(
                "ALBUMPICKERCORE_PRODUCT_DIR",
                str(
                    self.script_dir.parent.parent.parent.parent.parent.parent
                    / "tuikit_engine"
                    / "atomicx"
                    / "swift"
                    / "AlbumPickerCore"
                    / "product"
                ),
            )
        )

        # 临时目录：存放解压的核心层产物和临时 podspec（放在源码目录外）
        self.staging_dir = self.app_dir / "_albumpicker_build_staging"

        # 构建配置
        self.scheme_name = "AlbumPicker"
        self.bundle_name = "AlbumPickerBundle"
        self.configuration = "Release"
        # DerivedData 放在源码目录外，避免被 podspec 的 '**/*.{swift,h,m}' 通配符扫到
        self.derived_data_path = self.app_dir / "DerivedData" / "AlbumPicker"
        self.version = None  # 通过 --version 参数传入

        # Podfile 原始内容备份
        self._podfile_backup = None

        # 支持的平台
        self.platforms = {
            "iOS": {
                "destination": "generic/platform=iOS",
            },
            "iOS Simulator": {
                "destination": "generic/platform=iOS Simulator",
            },
        }

    def log(self, message, level="INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")

    def run_command(self, command, cwd=None, check=True):
        if isinstance(command, list):
            cmd_str = " ".join(command)
        else:
            cmd_str = command
            command = command.split()

        self.log(f"执行命令: {cmd_str}")

        try:
            result = subprocess.run(
                command, cwd=cwd, check=check,
                capture_output=True, text=True,
            )
            if result.stdout:
                self.log(f"输出: {result.stdout.strip()}")
            return result
        except subprocess.CalledProcessError as e:
            self.log(f"命令执行失败: {e}", "ERROR")
            if e.stdout:
                # 只打印最后 50 行，避免日志过长
                tail = "\n".join(e.stdout.splitlines()[-50:])
                self.log(f"标准输出(末尾):\n{tail}", "ERROR")
            if e.stderr:
                self.log(f"错误输出: {e.stderr}", "ERROR")
            raise

    # ------------------------------------------------------------------
    # 核心层产物准备
    # ------------------------------------------------------------------

    def prepare_core_binary(self):
        """解压核心层 zip 产物，并生成临时 podspec"""
        self.log("准备核心层二进制产物...")

        # 清理 staging 目录
        if self.staging_dir.exists():
            shutil.rmtree(self.staging_dir)
        self.staging_dir.mkdir(parents=True)

        # 查找核心层 zip（支持 AlbumPickerCore.zip 或 AlbumPickerCore_版本号.zip）
        core_zip = self.core_product_dir / "AlbumPickerCore.zip"
        if not core_zip.exists():
            # 按通配符查找带版本号的 zip
            import glob
            pattern = str(self.core_product_dir / "AlbumPickerCore*.zip")
            matches = sorted(glob.glob(pattern))
            if matches:
                core_zip = Path(matches[-1])  # 取最新的
            else:
                raise Exception(
                    f"未找到核心层产物: {pattern}\n"
                    "请先执行核心层构建脚本，或通过环境变量 "
                    "ALBUMPICKERCORE_PRODUCT_DIR 指定产物目录"
                )

        # 解压 xcframework + bundle
        self.log(f"解压核心层产物: {core_zip}")
        with zipfile.ZipFile(core_zip, "r") as zf:
            zf.extractall(self.staging_dir)

        # 如果 zip 中没有 bundle，从产物目录单独复制
        bundle_in_staging = self.staging_dir / "AlbumPickerCoreBundle.bundle"
        if not bundle_in_staging.exists():
            core_bundle = self.core_product_dir / "AlbumPickerCoreBundle.bundle"
            if core_bundle.exists():
                shutil.copytree(core_bundle, bundle_in_staging)
                self.log("已从产物目录复制 AlbumPickerCoreBundle.bundle")
            self.log("已复制 AlbumPickerCoreBundle.bundle")

        # 生成临时 podspec
        self._generate_core_podspec()

    def _generate_core_podspec(self):
        """生成临时 AlbumPickerCore.podspec（vendored_frameworks 模式）"""
        podspec_content = f"""\
Pod::Spec.new do |s|
  s.name             = 'AlbumPickerCore'
  s.version          = '0.0.1-local'
  s.summary          = 'AlbumPickerCore binary for build.'
  s.homepage         = 'https://trtc.io/'
  s.license          = {{ :type => 'MIT' }}
  s.authors          = 'trtc.io'
  s.source           = {{ :git => 'file://{self.staging_dir}', :tag => s.version.to_s }}
  s.ios.deployment_target = '13.0'

  s.dependency 'TXIMSDK_Plus_iOS_XCFramework'

  s.vendored_frameworks = ['AlbumPickerCore.xcframework']
  s.resource = 'AlbumPickerCoreBundle.bundle'
end
"""
        podspec_path = self.staging_dir / "AlbumPickerCore.podspec"
        with open(podspec_path, "w") as f:
            f.write(podspec_content)
        self.log(f"已生成临时 podspec: {podspec_path}")

    # ------------------------------------------------------------------
    # Podfile 注入与还原
    # ------------------------------------------------------------------

    def inject_podfile(self):
        """修改宿主 Podfile：AlbumPicker 源码 + AlbumPickerCore 二进制
        同时注释掉与 AlbumPicker 构建无关的 :path 依赖和不可用的 source，
        避免在 CI/Linux 环境中因路径不存在导致 pod install 失败。
        如果 Podfile 中没有 AlbumPicker 相关行，则主动插入。
        """
        import re

        self.log(f"注入构建依赖到 Podfile: {self.podfile_path}")

        with open(self.podfile_path, "r") as f:
            self._podfile_backup = f.read()

        # AlbumPicker 构建需要保留的 pod（不注释）
        keep_pods = {
            "AlbumPicker",
            "AlbumPickerCore",
        }

        # AlbumPicker podspec 路径（相对于 Podfile）
        albumpicker_podspec = self.script_dir / "AlbumPicker.podspec"
        try:
            albumpicker_rel = os.path.relpath(albumpicker_podspec, self.app_dir)
        except ValueError:
            albumpicker_rel = str(albumpicker_podspec)

        found_albumpicker = False
        found_albumpickercore = False

        lines = self._podfile_backup.splitlines(keepends=True)
        new_lines = []
        for line in lines:
            stripped = line.lstrip()

            # 注释掉指向本地路径的 source（CI 环境不存在）
            if (
                not stripped.startswith("#")
                and stripped.startswith("source")
                and "local-spec-repo" in stripped
            ):
                new_lines.append(f"# {line}" if not line.startswith("#") else line)
                continue

            # AlbumPickerCore :path 行 -> 改为指向 staging
            if (
                "AlbumPickerCore'" in stripped
                and ":path=>" in stripped
            ):
                new_lines.append(
                    f"  pod 'AlbumPickerCore', "
                    f":path => '{self.staging_dir}'\n"
                )
                found_albumpickercore = True
            # AlbumPicker :path 行 -> 启用
            elif (
                "AlbumPicker'" in stripped
                and ":path=>" in stripped
                and "AlbumPicker.podspec" in stripped
            ):
                new_lines.append(
                    line.replace("#  pod", "  pod")
                        .replace("# pod", " pod")
                )
                found_albumpicker = True
            # spec repo 模式的 AlbumPicker -> 替换为源码模式
            elif re.match(r"^\s*#?\s*pod\s+'AlbumPicker'\s*$", stripped):
                new_lines.append(
                    f"  pod 'AlbumPicker', "
                    f":path => '{albumpicker_rel}'\n"
                )
                found_albumpicker = True
            # 注释掉与 AlbumPicker 无关的 :path/:podspec 依赖
            elif (
                not stripped.startswith("#")
                and re.match(r"^\s*pod\s+'", stripped)
                and (":path" in stripped or ":podspec" in stripped)
            ):
                m = re.match(r"^\s*pod\s+'([^']+)'", stripped)
                pod_name = m.group(1).split("/")[0] if m else ""
                if pod_name in keep_pods:
                    new_lines.append(line)
                else:
                    new_lines.append(f"#  {stripped}")
                    if not line.endswith("\n"):
                        new_lines.append("\n")
            else:
                new_lines.append(line)

        # 兜底：如果 Podfile 中完全没有 AlbumPicker 相关行，在 use_frameworks! 后插入
        if not found_albumpicker or not found_albumpickercore:
            self.log("Podfile 中未找到 AlbumPicker 相关行，主动插入")
            final_lines = []
            inserted = False
            for line in new_lines:
                final_lines.append(line)
                if not inserted and "use_frameworks!" in line:
                    if not found_albumpicker:
                        final_lines.append(
                            f"  pod 'AlbumPicker', "
                            f":path => '{albumpicker_rel}'\n"
                        )
                    if not found_albumpickercore:
                        final_lines.append(
                            f"  pod 'AlbumPickerCore', "
                            f":path => '{self.staging_dir}'\n"
                        )
                    inserted = True
            new_lines = final_lines

        with open(self.podfile_path, "w") as f:
            f.writelines(new_lines)

        self.log("Podfile 注入完成")

        # 打印注入后的 Podfile 内容，方便排查
        with open(self.podfile_path, "r") as f:
            self.log(f"注入后的 Podfile:\n{f.read()}")

    def restore_podfile(self):
        """还原 Podfile"""
        if self._podfile_backup is None:
            self.log("无 Podfile 备份，跳过还原", "WARNING")
            return

        self.log("还原 Podfile")
        with open(self.podfile_path, "w") as f:
            f.write(self._podfile_backup)
        self._podfile_backup = None
        self.log("Podfile 已还原")

    def run_pod_install(self):
        """在宿主工程目录下执行 pod install"""
        self.log(f"在 {self.app_dir} 执行 pod install...")

        result = subprocess.run(
            ["pod", "install"],
            cwd=str(self.app_dir),
            capture_output=True, text=True,
            timeout=300,
        )

        if result.returncode != 0:
            self.log(f"pod install stdout: {result.stdout}", "ERROR")
            self.log(f"pod install stderr: {result.stderr}", "ERROR")
            raise Exception("pod install 失败")

        self.log("pod install 成功")

        # 打印可用 scheme 列表，方便排查
        try:
            result = subprocess.run(
                ["xcodebuild", "-workspace", str(self.workspace_path), "-list"],
                cwd=str(self.app_dir),
                capture_output=True, text=True, timeout=30,
            )
            schemes = [l.strip() for l in result.stdout.splitlines()
                       if l.strip() and not l.strip().startswith(("Information", "Schemes", "Build", "Targets"))]
            self.log(f"可用 schemes: {schemes}")
        except Exception:
            pass

    # ------------------------------------------------------------------
    # 构建
    # ------------------------------------------------------------------

    def clean_build(self):
        self.log("清理构建目录...")
        if self.derived_data_path.exists():
            shutil.rmtree(self.derived_data_path)
            self.log(f"已清理: {self.derived_data_path}")
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
            self.log(f"已清理: {self.output_dir}")
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def build_for_platform(self, platform_name, platform_config):
        self.log(f"开始构建 {platform_name} 平台...")

        archive_path = (
            self.derived_data_path
            / f"{self.scheme_name}-"
              f"{platform_name.replace(' ', '')}.xcarchive"
        )

        cmd = [
            "xcodebuild", "archive",
            "-workspace", str(self.workspace_path),
            "-scheme", self.scheme_name,
            "-configuration", self.configuration,
            "-destination", platform_config["destination"],
            "-archivePath", str(archive_path),
            "-derivedDataPath", str(self.derived_data_path),
            "SKIP_INSTALL=NO",
            "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
            "MACH_O_TYPE=mh_dylib",
        ]

        self.run_command(cmd)

        if not archive_path.exists():
            raise Exception(f"构建失败，未生成archive: {archive_path}")

        self.log(f"{platform_name} 平台构建完成: {archive_path}")
        return archive_path

    def create_xcframework(self, archives):
        self.log("创建xcframework...")

        xcframework_path = (
            self.output_dir / f"{self.scheme_name}.xcframework"
        )
        cmd = ["xcodebuild", "-create-xcframework"]

        for archive_path in archives:
            fw = (
                archive_path / "Products" / "Library"
                / "Frameworks" / f"{self.scheme_name}.framework"
            )
            if fw.exists():
                cmd.extend(["-framework", str(fw)])
            else:
                alt = (
                    archive_path / "Products" / "usr"
                    / "local" / "lib"
                    / f"{self.scheme_name}.framework"
                )
                if alt.exists():
                    cmd.extend(["-framework", str(alt)])
                else:
                    self.log(
                        f"警告: 未找到framework: {archive_path}", "WARNING"
                    )

        cmd.extend(["-output", str(xcframework_path)])
        self.run_command(cmd)

        if not xcframework_path.exists():
            raise Exception(f"xcframework创建失败: {xcframework_path}")

        self.log(f"xcframework创建成功: {xcframework_path}")
        return xcframework_path

    def copy_resource_bundle(self):
        self.log("查找 resource bundle...")
        bundle_name = f"{self.bundle_name}.bundle"

        for root, dirs, _files in os.walk(self.derived_data_path):
            if bundle_name in dirs:
                src = Path(root) / bundle_name
                dst = self.output_dir / bundle_name
                if dst.exists():
                    shutil.rmtree(dst)
                shutil.copytree(src, dst)
                self.log(f"已复制 {bundle_name}: {dst}")
                return dst

        self.log(f"警告: 未找到 {bundle_name}", "WARNING")
        return None

    def stamp_bundle_version(self):
        """将版本号写入所有 resource bundle 的 Info.plist（顶层 + xcframework 内）"""
        if not self.version:
            return

        bundle_filename = f"{self.bundle_name}.bundle"
        xcfw_path = self.output_dir / f"{self.scheme_name}.xcframework"

        # 收集所有需要 stamp 的 bundle 路径
        plist_paths = []

        # 顶层 bundle
        top_plist = self.output_dir / bundle_filename / "Info.plist"
        if top_plist.exists():
            plist_paths.append(top_plist)

        # xcframework 内每个架构的 bundle
        if xcfw_path.exists():
            for root, dirs, _ in os.walk(str(xcfw_path)):
                if bundle_filename in dirs:
                    inner_plist = Path(root) / bundle_filename / "Info.plist"
                    if inner_plist.exists():
                        plist_paths.append(inner_plist)

        if not plist_paths:
            self.log(f"未找到任何 {bundle_filename}/Info.plist，跳过版本号写入", "WARNING")
            return

        for plist_path in plist_paths:
            self.log(f"写入版本号 {self.version} 到 {plist_path}")
            subprocess.run(
                ["plutil", "-replace", "CFBundleShortVersionString",
                 "-string", self.version, str(plist_path)],
                check=True,
            )

        self.log(f"版本号已写入 {len(plist_paths)} 个 bundle: {self.version}")

    # ------------------------------------------------------------------
    # 构建信息
    # ------------------------------------------------------------------

    def generate_build_info(self, xcframework_path):
        self.log("生成构建信息...")
        build_info = {
            "name": self.scheme_name,
            "version": self.get_version(),
            "build_time": datetime.now().isoformat(),
            "configuration": self.configuration,
            "platforms": list(self.platforms.keys()),
            "xcframework_path": str(
                xcframework_path.relative_to(self.output_dir)
            ),
            "size": self.get_directory_size(xcframework_path),
        }
        info_file = self.output_dir / "build_info.json"
        with open(info_file, "w", encoding="utf-8") as f:
            json.dump(build_info, f, indent=2, ensure_ascii=False)
        self.log(f"构建信息已保存: {info_file}")
        return build_info

    def get_version(self):
        """获取版本号，优先使用 --version 传入的值"""
        if self.version:
            return self.version
        try:
            result = self.run_command(
                ["git", "describe", "--tags", "--always"], check=False
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return "1.0.0"

    def get_directory_size(self, path):
        total = 0
        for dp, _dn, fns in os.walk(path):
            for fn in fns:
                total += os.path.getsize(os.path.join(dp, fn))
        return total

    def generate_podspec(self, version):
        """生成 podspec 文件，放入产物目录"""
        self.log("生成 podspec...")

        content = f"""\
Pod::Spec.new do |s|
  s.name             = 'AlbumPicker'
  s.version          = '{version}'
  s.summary          = 'AlbumPicker binary framework.'
  s.homepage         = 'https://trtc.io/'
  s.license          = {{ :type => 'MIT' }}
  s.authors          = 'trtc.io'
  s.source           = {{ :http => '<ZIP_URL>/AlbumPicker.zip' }}
  s.ios.deployment_target = '13.0'

  s.dependency 'AlbumPickerCore', '{version}'

  s.vendored_frameworks = ['AlbumPicker.xcframework']
  s.resource = 'AlbumPickerBundle.bundle'
end
"""
        podspec_path = self.output_dir / "AlbumPicker.podspec"
        with open(podspec_path, "w") as f:
            f.write(content)

        self.log(f"podspec 已生成: {podspec_path}")
        self.log("请将 <ZIP_URL> 替换为实际的下载地址"
                 "（如 GitHub Releases URL）")

    # ------------------------------------------------------------------
    # 主流程
    # ------------------------------------------------------------------

    def build(self, platforms=None):
        try:
            self.log("开始AlbumPicker构建流程...")
            self.log(f"版本号: {self.get_version()}")

            # 前置检查
            try:
                result = self.run_command(["xcode-select", "-p"])
                self.log(f"Xcode路径: {result.stdout.strip()}")
            except subprocess.CalledProcessError:
                raise Exception("未找到Xcode")

            if not self.workspace_path.exists():
                raise Exception(f"未找到宿主工程: {self.workspace_path}")

            # 准备核心层二进制产物
            self.prepare_core_binary()

            # 清理上次构建残留
            self.clean_build()

            # 注入 Podfile 并 pod install
            self.inject_podfile()
            self.run_pod_install()

            if platforms is None:
                platforms = list(self.platforms.keys())

            # 构建各平台
            archives = []
            for name in platforms:
                if name not in self.platforms:
                    self.log(f"不支持的平台: {name}", "WARNING")
                    continue
                archives.append(
                    self.build_for_platform(name, self.platforms[name])
                )

            if not archives:
                raise Exception("没有成功构建任何平台")

            # 创建 xcframework
            xcframework_path = self.create_xcframework(archives)

            # 复制 resource bundle
            self.copy_resource_bundle()

            # 写入版本号到 bundle
            self.stamp_bundle_version()

            # 生成构建信息
            build_info = self.generate_build_info(xcframework_path)

            self.log("构建完成!")
            self.log(f"输出目录: {self.output_dir}")
            self.log(f"xcframework: {xcframework_path}")
            self.log(f"大小: {build_info['size'] / 1024 / 1024:.2f} MB")

            # 压缩 XCFramework + Resource Bundle
            zip_path = self.output_dir / f"{self.scheme_name}.zip"
            self.log(f"正在压缩产物到: {zip_path}")
            try:
                with zipfile.ZipFile(
                    zip_path, "w", zipfile.ZIP_DEFLATED
                ) as zf:
                    # 打入 xcframework
                    for root, _dirs, files in os.walk(xcframework_path):
                        for f in files:
                            fp = os.path.join(root, f)
                            arcname = os.path.join(
                                f"{self.scheme_name}.xcframework",
                                os.path.relpath(fp, xcframework_path),
                            )
                            zf.write(fp, arcname)

                    # 打入 resource bundle
                    bundle_path = (
                        self.output_dir / f"{self.bundle_name}.bundle"
                    )
                    if bundle_path.exists():
                        for root, _dirs, files in os.walk(bundle_path):
                            for f in files:
                                fp = os.path.join(root, f)
                                arcname = os.path.join(
                                    f"{self.bundle_name}.bundle",
                                    os.path.relpath(fp, bundle_path),
                                )
                                zf.write(fp, arcname)

                self.log(f"产物压缩成功: {zip_path}")
            except Exception as e:
                self.log(f"压缩失败: {e}", "ERROR")

            # 生成 podspec
            self.generate_podspec(build_info["version"])

            return True

        except Exception as e:
            self.log(f"构建失败: {e}", "ERROR")
            return False
        finally:
            # 只有注入过 Podfile 才需要还原
            if self._podfile_backup is not None:
                try:
                    self.restore_podfile()
                except Exception as e:
                    self.log(f"还原 Podfile 失败: {e}", "WARNING")
                try:
                    self.run_pod_install()
                except Exception as e:
                    self.log(f"还原后 pod install 失败（CI 环境可忽略）: {e}", "WARNING")
            # 清理 staging 目录
            if self.staging_dir.exists():
                shutil.rmtree(self.staging_dir, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(
        description="AlbumPicker Release Build Script"
    )
    parser.add_argument(
        "--platforms", nargs="+",
        choices=["iOS", "iOS Simulator"],
        default=["iOS", "iOS Simulator"],
        help="要构建的平台 (默认: iOS, iOS Simulator)",
    )
    parser.add_argument(
        "--core-product-dir",
        help="核心层产物目录路径（包含 AlbumPickerCore.zip）",
    )
    parser.add_argument(
        "--clean", action="store_true",
        help="仅清理构建目录",
    )
    parser.add_argument(
        "--version",
        help="版本号（写入 bundle Info.plist 的 CFBundleShortVersionString）",
    )

    args = parser.parse_args()

    builder = AlbumPickerBuilder()

    if args.core_product_dir:
        builder.core_product_dir = Path(args.core_product_dir)

    if args.version:
        builder.version = args.version

    if args.clean:
        builder.clean_build()
        print("清理完成")
        return

    success = builder.build(platforms=args.platforms)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
