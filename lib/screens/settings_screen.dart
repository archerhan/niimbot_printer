import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/code_generator.dart';
import '../models/app_settings.dart';
import '../services/label_printer.dart';
import '../services/label_renderer.dart';
import '../services/permission_service.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _a = TextEditingController();
  final TextEditingController _b = TextEditingController();
  final TextEditingController _c = TextEditingController();
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _offsetX = TextEditingController();
  final TextEditingController _offsetY = TextEditingController();
  final TextEditingController _labelWidthMm = TextEditingController();
  final TextEditingController _labelHeightMm = TextEditingController();
  final TextEditingController _labelDpi = TextEditingController();
  final TextEditingController _fontSize = TextEditingController();
  final TextEditingController _density = TextEditingController();
  bool _continuous = false;
  bool _testing = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final s = AppScope.of(context).settings.settings;
    _a.text = s.prefixA;
    _b.text = s.prefixB;
    _c.text = s.prefixC;
    _serial.text = s.serialNumber.toString();
    _offsetX.text = s.offsetX.toString();
    _offsetY.text = s.offsetY.toString();
    _labelWidthMm.text = _fmt(s.labelWidthMm);
    _labelHeightMm.text = _fmt(s.labelHeightMm);
    _labelDpi.text = s.labelDpi.toString();
    _fontSize.text = s.fontSize.toStringAsFixed(0);
    _density.text = s.density.toString();
    _continuous = s.continuousMode;
    _initialized = true;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _a,
      _b,
      _c,
      _serial,
      _offsetX,
      _offsetY,
      _labelWidthMm,
      _labelHeightMm,
      _labelDpi,
      _fontSize,
      _density,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reconnect() async {
    final controller = AppScope.of(context);

    final granted = await const PermissionService().ensureBluetooth();
    if (!granted) {
      if (mounted) {
        await showAlert(
          context,
          title: '缺少蓝牙权限',
          message: '请在系统设置中授予蓝牙扫描与连接权限。',
        );
      }
      return;
    }
    if (!mounted) return;

    List<BluetoothDevice> devices = const <BluetoothDevice>[];
    try {
      devices = await controller.scan();
    } catch (error) {
      if (mounted) {
        await showAlert(context, title: '扫描失败', message: '$error');
      }
      return;
    }
    if (!mounted) return;

    if (devices.isEmpty) {
      await showAlert(
        context,
        title: '未找到打印机',
        message: '请确认 B1 已开机、蓝牙已开启，并处于配对状态。',
      );
      return;
    }

    final device = await showDevicePicker(context, devices);
    if (device == null || !mounted) return;

    try {
      await controller.connect(device);
    } catch (error) {
      if (mounted) {
        await showAlert(context, title: '连接失败', message: '$error');
      }
      return;
    }
    if (mounted) setState(() {});
  }

  String _fmt(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  Future<void> _testPrint() async {
    final controller = AppScope.of(context);
    if (!controller.isConnected) {
      await showAlert(context, title: '打印机未连接', message: '请先连接打印机后再测试。');
      return;
    }

    final s = controller.settings.settings;
    setState(() => _testing = true);
    try {
      final page = await const LabelRenderer().buildPage(
        qrContent: '!TEST#MDE:TEST@RESULT:OK',
        lines: const <String>['TEST', 'TEST', 'TEST-0000'],
        pageWidth: s.labelWidthPx,
        pageHeight: s.labelHeightPx,
        offsetX: s.offsetX,
        offsetY: s.offsetY,
        fontSize: s.fontSize.round(),
      );
      await controller.printer.printPage(
        page,
        density: s.density,
        taskPreference: s.printTaskPreference,
      );
      if (mounted) {
        await showAlert(
          context,
          title: '测试打印完成',
          message:
              '任务：${controller.printer.lastPrintTask}'
              '（${controller.printer.lastPrintTaskReason}）',
        );
      }
    } catch (error) {
      if (mounted) {
        await showAlert(
          context,
          title: '测试打印失败',
          message:
              '${describePrinterError(error)}\n\n'
              '任务：${controller.printer.lastPrintTask}'
              '（${controller.printer.lastPrintTaskReason}）',
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final old = controller.settings.settings;

    final newA = _a.text.trim();
    final newB = _b.text.trim();
    final newC = _c.text.trim();
    final prefixChanged =
        newA != old.prefixA || newB != old.prefixB || newC != old.prefixC;

    if (prefixChanged) {
      final ok = await showConfirm(
        context,
        title: '修改前缀将重置序号',
        message: '前缀已变更，序号将重置为 0001，是否继续？',
        confirmText: '继续',
      );
      if (!ok) return;
      await controller.settings.changePrefix(a: newA, b: newB, c: newC);
    } else {
      final serial = int.tryParse(_serial.text.trim());
      if (serial == null || !const CodeGenerator().isSerialInRange(serial)) {
        await showAlert(
          context,
          title: '序号无效',
          message: '序号需为 1 ~ ${CodeGenerator.maxSerial} 的整数。',
        );
        return;
      }
      await controller.settings.setSerialNumber(serial);
    }

    await controller.settings.setContinuousMode(_continuous);
    if (!mounted) return;

    final labelWidthMm = double.tryParse(_labelWidthMm.text.trim());
    final labelHeightMm = double.tryParse(_labelHeightMm.text.trim());
    final labelDpi = int.tryParse(_labelDpi.text.trim());
    if (labelWidthMm == null || labelWidthMm < 5 || labelWidthMm > 120) {
      await showAlert(context, title: '纸张宽度无效', message: '宽度需为 5 ~ 120 毫米。');
      return;
    }
    if (labelHeightMm == null || labelHeightMm < 5 || labelHeightMm > 500) {
      await showAlert(context, title: '纸张高度无效', message: '高度需为 5 ~ 500 毫米。');
      return;
    }
    if (labelDpi == null || labelDpi < 100 || labelDpi > 600) {
      await showAlert(
        context,
        title: 'DPI 无效',
        message: 'DPI 需为 100 ~ 600（B1 为 203，Z401 为 300）。',
      );
      return;
    }
    await controller.settings.setLabelWidthMm(labelWidthMm);
    await controller.settings.setLabelHeightMm(labelHeightMm);
    await controller.settings.setLabelDpi(labelDpi);
    if (!mounted) return;

    final density = int.tryParse(_density.text.trim());
    if (density == null || density < 1 || density > 15) {
      await showAlert(
        context,
        title: '打印浓度无效',
        message: '浓度需为 1 ~ 15（B1 为 1~5，Z401 为 1~15）。',
      );
      return;
    }
    await controller.settings.setDensity(density);

    await controller.settings.setOffsetX(
      int.tryParse(_offsetX.text.trim()) ?? old.offsetX,
    );
    await controller.settings.setOffsetY(
      int.tryParse(_offsetY.text.trim()) ?? old.offsetY,
    );
    await controller.settings.setFontSize(
      double.tryParse(_fontSize.text.trim()) ?? old.fontSize,
    );
    if (!mounted) return;
    await showAlert(context, title: '已保存');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShadCard(
            title: const Text('产品编号前缀'),
            description: const Text('修改任一前缀都会重置序号'),
            child: Column(
              children: [
                _field('前缀 A', _a),
                _field('前缀 B', _b),
                _field('前缀 C', _c),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('序号'),
            description: const Text('手动修正当前序号（1 ~ 9999）'),
            child: _field('当前序号', _serial, keyboardType: TextInputType.number),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('连续模式'),
            description: const Text('开启后扫码直接打印，跳过预览'),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShadSwitch(
                value: _continuous,
                onChanged: (v) => setState(() => _continuous = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印纸尺寸'),
            description: const Text(
              '单位：毫米（像素 = 毫米 × DPI ÷ 25.4）。\n'
              'DPI：B1 为 203，Z401 为 300，连接后自动识别',
            ),
            child: Column(
              children: [
                _field(
                  '宽度（毫米）',
                  _labelWidthMm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _field(
                  '高度（毫米）',
                  _labelHeightMm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _field('DPI', _labelDpi, keyboardType: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('标签排版微调'),
            description: const Text('用于现场校正位置与字号'),
            child: Column(
              children: [
                _field('X 偏移', _offsetX, keyboardType: TextInputType.number),
                _field('Y 偏移', _offsetY, keyboardType: TextInputType.number),
                _field('字号', _fontSize, keyboardType: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印浓度'),
            description: const Text('B1 为 1~5，Z401 为 1~15'),
            child: _field('浓度', _density, keyboardType: TextInputType.number),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印机设备'),
            description: Text(controller.statusText),
            footer: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (controller.isConnected)
                  ShadButton.outline(
                    onPressed: () async {
                      await controller.disconnect();
                      if (mounted) setState(() {});
                    },
                    child: const Text('断开'),
                  ),
                const SizedBox(width: 8),
                ShadButton(onPressed: _reconnect, child: const Text('重新连接')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _compatCard(controller),
          const SizedBox(height: 16),
          _diagnosticsCard(controller),
          const SizedBox(height: 24),
          ShadButton(
            width: double.infinity,
            height: 48,
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 打印任务手动切换（兼容性设置，立即生效）。
  Widget _compatCard(AppController controller) {
    final current = controller.settings.settings.printTaskPreference;
    final diag = controller.printer.diagnostics(preference: current);
    return ShadCard(
      title: const Text('打印任务（兼容性）'),
      description: const Text(
        '部分型号（如 Z401/B32 系列）不在打印库的自动识别表中，'
        '将使用兜底任务。若打印异常，可在此逐个切换任务后测试打印。',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in PrinterTaskPreference.values)
                if (option == current)
                  ShadButton(onPressed: null, child: Text(option.label))
                else
                  ShadButton.outline(
                    onPressed: () async {
                      await controller.settings.setPrintTaskPreference(option);
                      if (mounted) setState(() {});
                    },
                    child: Text(option.label),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '当前将使用：${diag.resolvedTask}（${diag.resolvedReason}）',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// 打印机诊断信息（排查用）。
  Widget _diagnosticsCard(AppController controller) {
    final diag = controller.printer.diagnostics(
      preference: controller.settings.settings.printTaskPreference,
    );
    final printer = controller.printer;
    return ShadCard(
      title: const Text('打印机诊断'),
      description: Text(
        controller.isConnected
            ? '连接信息与当前任务解析结果；详细日志见运行控制台（标签见 [标签助手]）'
            : '打印机未连接时显示的是上次连接的信息',
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ShadButton.outline(
            onPressed: () => setState(() {}),
            child: const Text('刷新信息'),
          ),
          const SizedBox(width: 8),
          ShadButton(
            onPressed: _testing ? null : _testPrint,
            child: const Text('打印测试页'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _diagRow('设备', diag.deviceName ?? '-'),
          _diagRow(
            '型号',
            '${diag.modelName ?? '未知'}（ID ${diag.modelId ?? '-'}）',
          ),
          _diagRow(
            'DPI / 打印头',
            '${diag.dpi ?? '-'} dpi / ${diag.printheadPixels ?? '-'} px',
          ),
          _diagRow('协议版本', '${diag.protocolVersion ?? '-'}'),
          _diagRow('连接结果', diag.connectResult ?? '-'),
          _diagRow(
            '软件 / 硬件',
            '${diag.softwareVersion ?? '-'} / ${diag.hardwareVersion ?? '-'}',
          ),
          _diagRow('序列号', diag.serial ?? '-'),
          _diagRow('自动识别任务', diag.detectedTask ?? '未识别'),
          if (printer.lastPrintTask != null)
            _diagRow(
              '最近打印',
              '${printer.lastPrintTask}（${printer.lastPrintTaskReason}）',
            ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          ShadInput(controller: controller, keyboardType: keyboardType),
        ],
      ),
    );
  }
}
