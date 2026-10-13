import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/code_generator.dart';
import '../services/permission_service.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';
import 'series_list_screen.dart';

/// 设置页：产品系列入口 + 序号 + 打印相关参数。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _offsetX = TextEditingController();
  final TextEditingController _offsetY = TextEditingController();
  final TextEditingController _fontSize = TextEditingController();
  final TextEditingController _density = TextEditingController();
  final TextEditingController _labelWidthMm = TextEditingController();
  final TextEditingController _labelHeightMm = TextEditingController();
  final TextEditingController _labelDpi = TextEditingController();

  bool _continuous = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _loadFromSettings();
    _initialized = true;
  }

  void _loadFromSettings() {
    final controller = AppScope.of(context);
    final s = controller.settings.settings;
    _serial.text = s.currentSeries.serialNumber.toString();
    _offsetX.text = s.offsetX.toString();
    _offsetY.text = s.offsetY.toString();
    _fontSize.text = s.fontSize.toStringAsFixed(0);
    _density.text = s.density.toString();
    _labelWidthMm.text = _fmt(s.labelWidthMm);
    _labelHeightMm.text = _fmt(s.labelHeightMm);
    _labelDpi.text = s.labelDpi.toString();
    _continuous = s.continuousMode;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _serial,
      _offsetX,
      _offsetY,
      _fontSize,
      _density,
      _labelWidthMm,
      _labelHeightMm,
      _labelDpi,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _fmt(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  Future<void> _openSeriesManager() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SeriesListScreen()),
    );
    if (!mounted) return;
    // 系列可能已切换或序号已变，重新载入表单。
    setState(_loadFromSettings);
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
        message: '请确认打印机已开机、蓝牙已开启，并处于配对状态。',
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

    final serial = int.tryParse(_serial.text.trim());
    if (serial == null || !const CodeGenerator().isSerialInRange(serial)) {
      await showAlert(
        context,
        title: '序号无效',
        message: '序号需为 1 ~ ${CodeGenerator.maxSerial} 的整数。',
      );
      return;
    }

    final labelWidthMm = double.tryParse(_labelWidthMm.text.trim());
    final labelHeightMm = double.tryParse(_labelHeightMm.text.trim());
    final labelDpi = int.tryParse(_labelDpi.text.trim());
    if (labelWidthMm == null || labelWidthMm < 5 || labelWidthMm > 120) {
      await showAlert(
        context,
        title: '纸张宽度无效',
        message: '宽度需为 5 ~ 120 毫米。',
      );
      return;
    }
    if (labelHeightMm == null || labelHeightMm < 5 || labelHeightMm > 500) {
      await showAlert(
        context,
        title: '纸张高度无效',
        message: '高度需为 5 ~ 500 毫米。',
      );
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

    final density = int.tryParse(_density.text.trim());
    if (density == null || density < 1 || density > 15) {
      await showAlert(
        context,
        title: '打印浓度无效',
        message: '浓度需为 1 ~ 15（B1 为 1~5，Z401 为 1~15）。',
      );
      return;
    }

    final fontSize = double.tryParse(_fontSize.text.trim());
    if (fontSize == null || fontSize < 8 || fontSize > 200) {
      await showAlert(
        context,
        title: '字号无效',
        message: '字号需为 8 ~ 200。',
      );
      return;
    }

    await controller.settings.setCurrentSerial(serial);
    await controller.settings.setContinuousMode(_continuous);
    await controller.settings.setLabelWidthMm(labelWidthMm);
    await controller.settings.setLabelHeightMm(labelHeightMm);
    await controller.settings.setLabelDpi(labelDpi);
    await controller.settings
        .setOffsetX(int.tryParse(_offsetX.text.trim()) ?? old.offsetX);
    await controller.settings
        .setOffsetY(int.tryParse(_offsetY.text.trim()) ?? old.offsetY);
    await controller.settings.setFontSize(fontSize);
    await controller.settings.setDensity(density);

    if (!mounted) return;
    await showAlert(context, title: '已保存');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings.settings;
    final series = settings.currentSeries;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShadCard(
            title: const Text('产品系列'),
            description: const Text(
              '产品编号 = 前缀 A + 前缀 B + 前缀 C + 序号。\n'
              '不同产品系列的前缀不同，这里可以新增、修改、删除和切换。',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前系列', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  series.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '前缀：${_prefixPreview(series.prefixA, series.prefixB, series.prefixC)}'
                  '　序号：${series.serialNumber.toString().padLeft(settings.serialLength, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ShadButton.outline(
                    onPressed: _openSeriesManager,
                    child: const Text('管理产品系列'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('当前系列序号'),
            description: const Text(
              '下一次打印使用的序号，打印成功后会 +1。\n'
              '序号按系列各自记录，切换系列不会重置。',
            ),
            child: _field(
              '序号',
              _serial,
              keyboardType: TextInputType.number,
              helper: '范围 1 ~ ${CodeGenerator.maxSerial}',
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('连续模式'),
            description: const Text(
              '开启后，扫到配件码会跳过预览直接打印；\n'
              '打印失败或断连时会自动暂停并提示。',
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShadSwitch(
                value: _continuous,
                onChanged: (value) => setState(() => _continuous = value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印纸尺寸'),
            description: const Text(
              '填实际标签纸的毫米尺寸，预览与打印都按它换算。\n'
              'DPI 由打印机型号决定：B1 为 203，Z401 为 300（连接后自动识别）。',
            ),
            child: Column(
              children: [
                _field(
                  '宽度（毫米）',
                  _labelWidthMm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: '例如 40',
                ),
                _field(
                  '高度（毫米）',
                  _labelHeightMm,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: '例如 20',
                ),
                _field(
                  'DPI',
                  _labelDpi,
                  keyboardType: TextInputType.number,
                  helper: '每英寸打印点数，连接打印机后会自动更新',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('标签排版微调'),
            description: const Text(
              '打印位置有偏差时用这里的偏移量和字号微调，改完先看预览。',
            ),
            child: Column(
              children: [
                _field(
                  'X 偏移',
                  _offsetX,
                  keyboardType: TextInputType.number,
                  helper: '正数向右移，负数向左移（单位：像素）',
                ),
                _field(
                  'Y 偏移',
                  _offsetY,
                  keyboardType: TextInputType.number,
                  helper: '正数向下移，负数向上移（单位：像素）',
                ),
                _field(
                  '字号',
                  _fontSize,
                  keyboardType: TextInputType.number,
                  helper: '基准 24，标签文字太大或太小可调整',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印浓度'),
            description: const Text('字迹太淡就调大，太深（发糊）就调小。'),
            child: _field(
              '浓度',
              _density,
              keyboardType: TextInputType.number,
              helper: 'B1 为 1~5，Z401 为 1~15',
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印机设备'),
            description: Text('当前状态：${controller.statusText}'),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ShadButton(
                    onPressed: _reconnect,
                    child: const Text('重新连接打印机'),
                  ),
                  if (controller.isConnected)
                    ShadButton.outline(
                      onPressed: () async {
                        await controller.disconnect();
                        if (mounted) setState(() {});
                      },
                      child: const Text('断开连接'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ShadButton(
            width: double.infinity,
            height: 48,
            onPressed: _save,
            child: const Text('保存设置'),
          ),
          const SizedBox(height: 8),
          const Text(
            '「保存设置」保存本页的序号、纸张、排版与浓度；产品系列在「管理产品系列」里单独保存。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _prefixPreview(String a, String b, String c) {
    final parts = <String>[
      if (a.isNotEmpty) a,
      if (b.isNotEmpty) b,
      if (c.isNotEmpty) c,
    ];
    return parts.isEmpty ? '（空）' : parts.join(' + ');
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          ShadInput(controller: controller, keyboardType: keyboardType),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}
