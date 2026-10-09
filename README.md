# 标签打印（NIIMBOT B1）

面向精臣 B1 蓝牙标签打印机的 Android 应用：扫描配件二维码 → 预览确认 → 蓝牙打印标签。

## 功能

- 扫描配件二维码，取扫码原文作为配件编号。
- 自动维护自增产品编号（4 位，左补零，上限 9999）。
- 生成标签二维码内容：`!{产品编号}#MDE:{配件编号}@RESULT:OK`。
- 打印预览确认；连续模式（默认关闭）扫码后直接打印。
- 跳号警告、重复配件码选择（沿用旧编号 / 生成新编号）。
- 打印历史与重打（重打不占新序号）。
- 打印机自动连接与重连，设置页可微调标签排版。

详细需求见 [docs/PRD.md](docs/PRD.md)，开发任务见 [docs/开发任务拆解.md](docs/开发任务拆解.md)。

## 环境

- Flutter 3.41+（本项目在 Flutter 3.44 / Dart 3.12 验证）
- Android SDK，minSdk 21，目标 Android 12+

## 运行

```bash
flutter pub get
flutter run            # 连接 Android 设备后
flutter test           # 单元测试与控件测试
flutter analyze
```

## 打包

```bash
flutter build apk --release --target-platform android-arm64
```

## 自动打包与发布

推送 `v1.0.0+1` 形式的 tag 会自动触发 GitHub Actions 打包并创建 Release，
详见 [docs/发布流程.md](docs/发布流程.md)。

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

APK 仅包含 **arm64-v8a** 一个 ABI（约 27MB）：

- `--target-platform android-arm64` 只编译 Flutter 引擎的 arm64 版本。
- `android/app/build.gradle.kts` 中通过 `ndk.abiFilters` 与
  `packaging.jniLibs.excludes` 去除第三方预编译库的其它 ABI
  （如扫码用的 ML Kit `libbarhopper_v3.so`）。

> 只支持 64 位 ARM 设备（Android 12+ 主流机型均为 arm64-v8a）。

### 签名

- 签名密钥：`android/app/printer-release.jks`（PKCS12，alias `printer`）。
- 配置：`android/key.properties`（`storeFile` 相对于 `android/app`）。
- 若 `android/key.properties` 不存在，release 构建会回退到 debug 签名。

> ⚠️ 密钥与口令属于敏感信息，请勿提交到公开仓库。CI/CD 成熟后建议改用 GitHub Secrets 管理。

## 目录结构

```
lib/
  core/        纯逻辑：编号生成、跳号判断、打印任务模型
  models/      数据模型：设置、打印记录
  services/    设置存储、历史数据库、标签渲染、打印编排、蓝牙打印机
  screens/     界面：主界面、扫码、设置、历史
  state/       应用级状态与依赖注入
  widgets/     通用对话框
test/          单元测试与控件测试
docs/          需求、任务与参考资料
```

## 说明

- 打印部分基于 [`niim_blue_flutter`](https://pub.dev/packages/niim_blue_flutter)。
- 标签默认版式为 384 × 240 像素的估算值，需用真机标定后在设置中微调。
