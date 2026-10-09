# 精臣 B1 标签自动打印 App 开发交接文档

## 一、项目背景与目标

### 1.1 业务需求
公司现有精臣 B1 蓝牙标签打印机一台，需要开发一个 Android App，实现以下自动化打印流程：

1. 操作员用 App 扫描配件二维码，获取配件编号。
2. App 自动读取并维护一个自增的产品编号。
3. App 将「自增产品编号 + 扫码配件编号 + 固定符号」拼接成一段完整字符串，生成二维码。
4. 通过蓝牙将标签发送至精臣 B1 打印机完成打印。

### 1.2 现有工作方式的问题
- 官方「精臣云打印」App 无法将扫码结果作为变量注入标签模板。
- 产品编号需要手动输入或依赖 Excel 导入，效率低、易出错。

### 1.3 期望成果
一个可安装的 Android App，实现「扫一下配件码 → 自动生成标签 → 蓝牙打印」的一键式操作。

---

## 二、技术选型

| 项目       | 选型                                  | 说明                                                |
| :--------- | :------------------------------------ | :-------------------------------------------------- |
| 开发框架   | Flutter                               | 跨平台，后续可扩展 iOS                              |
| 打印通信库 | `niim_blue_flutter`                   | 基于开源项目 niimblue 封装，支持 B1 及 85+ 精臣型号 |
| 扫码       | `mobile_scanner` 或 `qr_code_scanner` | Flutter 生态成熟扫码插件                            |
| 本地存储   | `shared_preferences` 或 `sqflite`     | 用于持久化自增计数器                                |
| 目标平台   | Android（优先）                       | B1 为蓝牙打印机，Android 蓝牙权限需处理             |

### 2.1 核心依赖
```yaml
dependencies:
  flutter:
    sdk: flutter
  niim_blue_flutter: ^1.0.0
  mobile_scanner: ^5.0.0   # 或最新稳定版
  shared_preferences: ^2.0.0
  permission_handler: ^11.0.0
```

---

## 三、环境配置

### 3.1 Android 配置

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
```

在 `android/app/build.gradle` 中设置：

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### 3.2 iOS 配置（如需）

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>App needs Bluetooth to connect to NIIMBOT printers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>App needs Bluetooth to connect to NIIMBOT printers</string>
<key>NSCameraUsageDescription</key>
<string>需要相机权限用于扫描配件二维码</string>
```

在 `ios/Podfile` 中设置：

```ruby
platform :ios, '12.0'
```

然后执行 `cd ios && pod install`。

---

## 四、核心业务逻辑设计

### 4.1 数据拼接规则

最终二维码内容格式为：

```
!{产品编号}#MDE:{配件编号}@RESULT:OK
```

**示例：**
```
!ADM32672805CTX6O60005#MDE:MDE62564302CDFL9D@RESULT:OK
```

其中：
- `!`：固定前缀
- `ADM32672805CTX6O6`：产品编号固定前缀
- `0005`：自增序号（4 位，左补零）
- `#MDE:`：固定分隔符
- `MDE62564302CDFL9D`：扫码获取的配件编号
- `@RESULT:OK`：固定后缀

### 4.2 自增编号管理

建议维护两个值：

| 字段            | 说明               | 示例                |
| :-------------- | :----------------- | :------------------ |
| `productPrefix` | 产品编号固定前缀   | `ADM32672805CTX6O6` |
| `serialNumber`  | 自增序号（整数）   | `5`                 |
| `serialLength`  | 序号位数（左补零） | `4`                 |

**编号生成逻辑：**
```dart
String buildProductCode(String prefix, int serial, int length) {
  final padded = serial.toString().padLeft(length, '0');
  return '$prefix$padded';
}

// 示例：buildProductCode('ADM32672805CTX6O6', 5, 4) => 'ADM32672805CTX6O60005'
```

### 4.3 持久化策略

使用 `shared_preferences` 存储：

```dart
// 读取当前序号
final prefs = await SharedPreferences.getInstance();
int serial = prefs.getInt('serialNumber') ?? 1;

// 打印成功后递增
await prefs.setInt('serialNumber', serial + 1);
```

**关键注意点：**
- 建议在**打印任务成功回调后**才递增序号，避免打印失败导致编号跳号。
- 需提供「手动修正序号」的入口，方便在异常情况下校正。

### 4.4 界面结构建议

```
[主界面]
  ├── 显示当前产品编号（如：ADM32672805CTX6O60005）
  ├── [扫描配件二维码] 按钮
  │     └── 扫码成功后显示配件编号
  ├── [打印标签] 按钮
  │     └── 触发蓝牙打印流程
  ├── 打印机连接状态指示
  └── 设置入口（修改前缀、序号起始值、手动修正序号）
```

---

## 五、核心代码示例

### 5.1 连接打印机

```dart
import 'package:niim_blue_flutter/niim_blue_flutter.dart';

final client = NiimbotBluetoothClient();
await client.connect(); // 自动扫描并连接第一台精臣设备
```

如需指定设备：
```dart
await client.connect(deviceId: 'XX:XX:XX:XX:XX:XX');
```

### 5.2 扫码获取配件编号

```dart
import 'package:mobile_scanner/mobile_scanner.dart';

final controller = MobileScannerController();
// 在扫码回调中获取 rawValue
final scannedCode = barcode.rawValue ?? '';
// 按业务规则解析出配件编号
```

### 5.3 构建标签页面

```dart
final page = PrintPage(400, 240); // B1 标签像素尺寸参考值，需按实际标签调整

// 绘制二维码（内容为拼接后的完整字符串）
page.addQR(
  qrContent,
  QROptions(
    x: 100,
    y: 120,
    width: 120,
    height: 120,
    ecl: QRErrorCorrectLevel.M,
  ),
);

// 绘制三行产品编号文本
page.addText('ADM32672805', TextOptions(x: 250, y: 60, fontSize: 20));
page.addText('CTX', TextOptions(x: 250, y: 100, fontSize: 20));
page.addText('6O6-0005', TextOptions(x: 250, y: 140, fontSize: 20));
```

### 5.4 执行打印

```dart
client.stopHeartbeat();
client.setPacketInterval(0); // 快速打印

final task = client.createPrintTask(PrintOptions(
  totalPages: 1,
  density: 3, // 打印浓度 1-5，默认 3
  labelType: 1,
));

if (task == null) {
  throw Exception('打印机型号未识别');
}

await task.printInit();
await task.printPage(page.toEncodedImage(), 1);
await task.waitForFinished();

client.startHeartbeat();

// 打印成功后再递增序号
await prefs.setInt('serialNumber', serial + 1);
```

### 5.5 打印预览（调试用）

```dart
final pngBytes = await page.toPreviewImage();
// 使用 Image.memory(pngBytes) 显示预览，确认排版无误
```

---

## 六、接口说明摘要

### 6.1 NiimbotBluetoothClient

| 方法                                 | 说明                             |
| :----------------------------------- | :------------------------------- |
| `connect({String? deviceId})`        | 连接打印机（自动扫描或指定设备） |
| `disconnect()`                       | 断开连接                         |
| `setOnDisconnect(callback)`          | 设置断连回调                     |
| `listDevices({Duration? timeout})`   | 列出可用打印机                   |
| `listConnectedDevices()`             | 列出已连接设备                   |
| `createPrintTask(PrintOptions?)`     | 创建打印任务                     |
| `setPacketInterval(int ms)`          | 设置数据包间隔（0 最快）         |
| `startHeartbeat() / stopHeartbeat()` | 心跳控制                         |

### 6.2 PrintPage 方法

| 方法                                         | 说明             |
| :------------------------------------------- | :--------------- |
| `addText(String, TextOptions)`               | 绘制文本         |
| `addQR(String, QROptions)`                   | 绘制二维码       |
| `addBarcode(String, BarcodeOptions)`         | 绘制条形码       |
| `addImageFromBuffer(ImageFromBufferOptions)` | 绘制图片         |
| `addLine(LineOptions)`                       | 绘制直线         |
| `toEncodedImage()`                           | 转换为打印机格式 |
| `toPreviewImage()`                           | 生成 PNG 预览    |

### 6.3 关键参数

**PrintOptions：**
- `totalPages`：打印页数
- `density`：浓度 1-5，默认 3
- `labelType`：标签类型标识（型号相关）

**QROptions：**
- `x`、`y`：坐标
- `width`、`height`：尺寸
- `ecl`：纠错等级（L / M / Q / H）
- `align`、`vAlign`：对齐方式
- `rotate`：旋转角度

**TextOptions：**
- `fontSize`、`fontFamily`、`fontWeight`
- `align`、`vAlign`、`rotate`

---

## 七、测试要点

1. **蓝牙连接**：测试首次连接、断连重连、多设备场景。
2. **扫码解析**：确保各类配件二维码都能正确解析出配件编号。
3. **二维码内容验证**：打印后用手机扫一扫，确认内容与预期完全一致。
4. **自增序号**：连续打印多张，确认序号依次递增；App 重启后序号不丢失。
5. **打印质量**：根据实际效果调整 `density` 和标签排版坐标。
6. **异常处理**：
   - 打印中途断连
   - 标签纸用完
   - 扫码失败
   - 权限被拒绝

---

## 八、已知风险与注意事项

1. **标签尺寸需实测**：`PrintPage(400, 240)` 为参考值，B1 实际打印宽度为 384 点（48mm），需根据实际标签纸调整坐标。
2. **RFID 标签限制**：精臣 B1 使用 RFID 标签纸，必须使用原装或兼容标签纸，否则可能无法打印。
3. **打印任务版本**：不同批次打印机可能需要选择不同的 print task 版本，`niim_blue_flutter` 已做自动检测。
4. **Android 12+ 权限**：蓝牙扫描和连接权限需在运行时动态申请，建议使用 `permission_handler` 统一处理。
5. **iOS 限制**：如需 iOS 版本，需注意 Web Bluetooth / BLE 权限配置，并在真机测试。
6. **序号安全**：自增序号建议加锁或单线程处理，避免并发时重复。

---

## 九、参考资源

- **niim_blue_flutter 包文档**：https://pub.dev/packages/niim_blue_flutter
- **niimblue 开源项目**：https://github.com/MultiMote/niimblue
- **精臣开发者支持**：精臣官网 → 开发者支持页面（申请官方 SDK 时参考）
- **Flutter 扫码插件**：https://pub.dev/packages/mobile_scanner
- **Flutter 本地存储**：https://pub.dev/packages/shared_preferences

---

## 十、交付清单

开发完成后需交付：

- [ ] Android APK 安装包
- [ ] 完整 Flutter 源码（含注释）
- [ ] 项目 README（含环境配置、编译步骤）
- [ ] 测试用例与测试报告
- [ ] 操作使用说明（面向最终用户）

---

如有技术细节需要进一步确认，可随时沟通。