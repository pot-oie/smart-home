# 智能家居监测项目

Flutter 手机客户端与 STM32F103 系列固件的课程协作仓库。日常使用 Mac 和 VS Code 开发。

客户端默认运行模拟设备，可交互展示监测、事件、RFID 名单与设置。温湿度和光照曾通过 ST-LINK 与 Mac 本地网关接入安卓模拟器；RFID 固件已写入过实物，但读卡仍在排查。无线直连尚未完成。

## 克隆与运行客户端

先按 [环境安装指南](docs/环境安装指南.md) 安装 Flutter、Android SDK 和模拟器。项目基线为 Flutter 3.41.6 / Dart 3.11.4；Android 使用 Gradle 8.13、AGP 8.11.2、Kotlin 2.0.21。

```sh
git clone https://github.com/pot-oie/smart-home.git
cd smart-home/客户端/home_observer
flutter pub get
flutter analyze
flutter test
flutter devices
```

启动 Android 模拟器，在 VS Code 打开客户端目录、选择安卓设备，然后 F5 运行“家居观察 · Android 调试”。也可执行以下命令，设备 ID 以自己的 `flutter devices` 输出为准：

```sh
flutter run -d emulator-5554 -t lib/main.dart
```

Android SDK 不自动下载；缺失组件请在 SDK Manager 安装。首次 clone 不使用 `--offline`。Flutter SDK 通过 PATH 或个人 VS Code 设置定位，仓库不固定开发者的 SDK 路径。

## 固件构建

安装 ST 官方 VS Code 扩展包和其 GNU Tools for STM32、CMake、Ninja、Programmer 工具包。两套工程已随仓库包含 HAL/CMSIS，无需子模块。

在仓库根目录运行：

```sh
python3 tools/build_firmware.py --project sensors
python3 tools/build_firmware.py --project rfid
```

输出分别位于对应固件目录的 `build/Debug/home_observer_board_test.elf`。构建只生成文件，不会自动烧录。macOS 默认从 ST 工具包目录发现工具；也支持 `ARM_GCC`、`STM32_CMAKE`、`STM32_NINJA`、`STM32_PROGRAMMER_CLI`、`ARM_NM` 环境变量指定可执行文件，以及 `CUBE_BUNDLE_PATH` 指定工具包目录。

用 CubeMX 修改引脚或生成代码时安装 STM32CubeF1 V1.8.7；项目历史使用 CubeMX 6.18.1、GNU Tools 14.3.1+st.2。不要对正式工程盲目重新生成代码。

## 目录

```text
客户端/home_observer/   Flutter 源码、资源、Android/iOS 工程与测试
硬件/温湿度与光照/      DHT12 和 BH1750 固件与 SWD 读取脚本
硬件/RFID/             在双传感器基础上增加 RC522 的独立工程
tools/                 通用 STM32 工具发现和构建脚本
docs/                  安装、接线、联调与协作说明
```

可打开 `smart-home.code-workspace` 同时查看三个工程。客户端 README 介绍页面与数据边界；[协作与联调](docs/协作与联调.md)说明固件版本、硬件接线和真实读数入口。

## 验证状态

软件构建与测试结果见 [验证记录](docs/验证记录.md)。这些结果不代表新电脑或全部实物已经验收。

最近实物状态：RFID 固件轮询计数增加，但 RC522 版本寄存器为 0x00、未获得 UID；当时温湿度与光照未接入。旧双传感器网关不能直接用于假定当前硬件已恢复的演示。

仓库不包含 SDK、构建缓存、APK、板上 Flash 备份、个人报告、学号或课堂原始资料。第三方驱动和字体保留原许可证，见 [第三方说明](THIRD_PARTY_NOTICES.md)。
