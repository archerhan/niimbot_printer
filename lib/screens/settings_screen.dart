import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/code_generator.dart';
import '../services/permission_service.dart';
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
  final TextEditingController _labelWidth = TextEditingController();
  final TextEditingController _labelHeight = TextEditingController();
  final TextEditingController _fontSize = TextEditingController();
  final TextEditingController _density = TextEditingController();
  bool _continuous = false;
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
    _labelWidth.text = s.labelWidth.toString();
    _labelHeight.text = s.labelHeight.toString();
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
      _labelWidth,
      _labelHeight,
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
      if (serial == null ||
          !const CodeGenerator().isSerialInRange(serial)) {
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

    final labelWidth = int.tryParse(_labelWidth.text.trim());
    final labelHeight = int.tryParse(_labelHeight.text.trim());
    if (labelWidth == null || labelWidth < 50 || labelWidth > 1200) {
      await showAlert(
        context,
        title: '纸张宽度无效',
        message: '宽度需为 50 ~ 1200 像素（B1 为 384 点，Z401 为 851 点）。',
      );
      return;
    }
    if (labelHeight == null || labelHeight < 50 || labelHeight > 2000) {
      await showAlert(
        context,
        title: '纸张高度无效',
        message: '高度需为 50 ~ 2000 像素。',
      );
      return;
    }
    await controller.settings.setLabelWidth(labelWidth);
    await controller.settings.setLabelHeight(labelHeight);
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

    await controller.settings
        .setOffsetX(int.tryParse(_offsetX.text.trim()) ?? old.offsetX);
    await controller.settings
        .setOffsetY(int.tryParse(_offsetY.text.trim()) ?? old.offsetY);
    await controller.settings
        .setFontSize(double.tryParse(_fontSize.text.trim()) ?? old.fontSize);
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
              '单位：像素（打印点）。B1 为 384 宽，Z401 为 851 宽',
            ),
            child: Column(
              children: [
                _field(
                  '宽度',
                  _labelWidth,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  '高度',
                  _labelHeight,
                  keyboardType: TextInputType.number,
                ),
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
                ShadButton(
                  onPressed: _reconnect,
                  child: const Text('重新连接'),
                ),
              ],
            ),
          ),
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
