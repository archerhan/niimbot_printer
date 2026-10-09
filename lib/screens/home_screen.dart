import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/code_generator.dart';
import '../core/label_job.dart';
import '../models/print_record.dart';
import '../services/permission_service.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const CodeGenerator _generator = CodeGenerator();

  bool _busy = false;

  Future<void> _connect() async {
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

    setState(() => _busy = true);
    List<BluetoothDevice> devices = const <BluetoothDevice>[];
    try {
      devices = await controller.scan();
    } catch (error) {
      if (mounted) {
        await showAlert(context, title: '扫描失败', message: '$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (devices.isEmpty) {
      await showAlert(
        context,
        title: '未找到打印机',
        message: '请确认 B1 已开机、手机蓝牙已开启，并处于配对状态。',
      );
      return;
    }

    final device = await showDevicePicker(context, devices);
    if (device == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await controller.connect(device);
    } catch (error) {
      if (mounted) {
        await showAlert(context, title: '连接失败', message: '$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final controller = AppScope.of(context);
    await controller.disconnect();
    if (mounted) setState(() {});
  }

  Future<void> _scanAccessory() async {
    final granted = await const PermissionService().ensureCamera();
    if (!granted) {
      if (mounted) {
        await showAlert(
          context,
          title: '缺少相机权限',
          message: '请在系统设置中授予相机权限。',
        );
      }
      return;
    }
    if (!mounted) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScanScreen()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    await _handleAccessory(code.trim());
  }

  Future<void> _handleAccessory(String accessoryCode) async {
    final controller = AppScope.of(context);
    final config = controller.settings.settings;

    PrintRecord? previous;
    try {
      previous = await controller.history.lastByAccessoryCode(accessoryCode);
    } catch (_) {
      previous = null;
    }

    var reuse = false;
    if (previous != null && mounted) {
      final choice = await showDuplicateDialog(
        context,
        accessoryCode: accessoryCode,
        previousProductCode: previous.productCode,
      );
      if (choice == null) return;
      reuse = choice == DuplicateChoice.reuse;
    }

    final LabelJob job;
    if (reuse && previous != null) {
      job = LabelJob.fromReused(
        accessoryCode: accessoryCode,
        productCode: previous.productCode,
        serial: previous.serial,
        qrContent: previous.qrContent,
        lines: previous.labelLines,
        originalId: previous.id ?? 0,
      );
    } else {
      job = LabelJob.build(settings: config, accessoryCode: accessoryCode);
    }

    if (!mounted) return;
    if (!_generator.isSerialInRange(job.serial) && !job.isReprint) {
      await showAlert(
        context,
        title: '序号超限',
        message: '当前序号 ${job.serial} 已超过上限 '
            '${CodeGenerator.maxSerial}，请在设置中调整。',
      );
      return;
    }

    final lastSuccess = await controller.history.lastSuccess();
    final shouldWarn = controller.skipChecker.shouldWarn(
      currentSerial: job.serial,
      lastSuccessSerial: lastSuccess?.serial,
    );
    if (shouldWarn && mounted) {
      final go = await showSkipWarning(
        context,
        currentSerial: job.serial,
        lastSuccessSerial: lastSuccess?.serial,
      );
      if (!go) return;
    }

    if (config.continuousMode) {
      await _printJob(job);
    } else {
      await _previewAndPrint(job);
    }
  }

  Future<void> _previewAndPrint(LabelJob job) async {
    final controller = AppScope.of(context);

    setState(() => _busy = true);
    Uint8List png;
    try {
      final page = await controller.printService.renderer.buildPage(
        qrContent: job.qrContent,
        lines: job.lines,
        offsetX: controller.settings.settings.offsetX,
        offsetY: controller.settings.settings.offsetY,
      );
      png = await controller.printService.renderer.preview(page);
    } catch (error) {
      if (mounted) {
        await showAlert(context, title: '预览生成失败', message: '$error');
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    final confirmed = await showShadDialog<bool>(
          context: context,
          builder: (ctx) => ShadDialog(
            title: const Text('打印预览'),
            description: Text('配件编号：${job.accessoryCode}'),
            actions: [
              ShadButton.outline(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              ShadButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('打印'),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(
                    png,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  job.productCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;
    await _printJob(job);
  }

  Future<void> _printJob(LabelJob job) async {
    final controller = AppScope.of(context);
    if (!controller.isConnected) {
      await showAlert(
        context,
        title: '打印机未连接',
        message: '请先连接精臣 B1 打印机。',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final outcome = await controller.printService.print(job);
      if (!mounted) return;
      if (outcome.success) {
        await showAlert(
          context,
          title: '打印成功',
          message: '产品编号：${job.productCode}',
        );
      } else {
        await showAlert(
          context,
          title: '打印失败',
          message: '${outcome.error}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _currentProductCode(AppController controller) {
    final s = controller.settings.settings;
    return _generator.buildProductCode(
      prefixA: s.prefixA,
      prefixB: s.prefixB,
      prefixC: s.prefixC,
      serial: s.serialNumber,
      serialLength: s.serialLength,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final config = controller.settings.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签打印'),
        actions: [
          IconButton(
            tooltip: '打印历史',
            icon: const Icon(Icons.history),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _connectionCard(controller),
          const SizedBox(height: 16),
          _codeCard(controller),
          const SizedBox(height: 16),
          _continuousCard(controller, config.continuousMode),
          const SizedBox(height: 24),
          ShadButton(
            width: double.infinity,
            onPressed: _busy ? null : _scanAccessory,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('扫描配件码'),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _connectionCard(AppController controller) {
    return ShadCard(
      title: const Text('打印机'),
      description: Text(controller.statusText),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (controller.isConnected)
            ShadButton.outline(
              onPressed: _busy ? null : _disconnect,
              child: const Text('断开'),
            )
          else
            ShadButton(
              onPressed: _busy ? null : _connect,
              child: const Text('连接打印机'),
            ),
        ],
      ),
    );
  }

  Widget _codeCard(AppController controller) {
    return ShadCard(
      title: const Text('当前产品编号'),
      child: SelectableText(
        _currentProductCode(controller),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _continuousCard(AppController controller, bool value) {
    return ShadCard(
      title: const Text('连续模式'),
      description: const Text('开启后，扫到配件码直接打印，跳过预览'),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ShadSwitch(
          value: value,
          onChanged: (next) async {
            await controller.settings.setContinuousMode(next);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }
}
