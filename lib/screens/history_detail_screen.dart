import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/label_job.dart';
import '../models/print_record.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';

/// 单条打印记录的详情，并提供重打。
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.record});

  final PrintRecord record;

  Future<void> _reprint(BuildContext context) async {
    final controller = AppScope.of(context);
    if (!controller.isConnected) {
      await showAlert(
        context,
        title: '打印机未连接',
        message: '请先连接精臣 B1 打印机。',
      );
      return;
    }

    final job = LabelJob.fromReused(
      accessoryCode: record.accessoryCode,
      productCode: record.productCode,
      serial: record.serial,
      qrContent: record.qrContent,
      lines: record.labelLines,
      originalId: record.id ?? 0,
    );
    final outcome = await controller.printService.print(job);
    if (!context.mounted) return;
    await showAlert(
      context,
      title: outcome.success ? '重打成功' : '重打失败',
      message: outcome.success
          ? '产品编号：${record.productCode}'
          : '${outcome.error}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final serialText = record.serial.toString().padLeft(4, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('打印详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShadCard(
            title: const Text('标签内容'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('产品编号', record.productCode, selectable: true),
                _row('配件编号', record.accessoryCode, selectable: true),
                _row('序号', serialText),
                _row('二维码内容', record.qrContent, selectable: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('打印信息'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('状态', record.success ? '打印成功' : '打印失败'),
                _row(
                  '类型',
                  record.isReprint
                      ? '重打（原记录 #${record.originalId ?? '-'}）'
                      : '正常打印',
                ),
                _row('时间', _formatTime(record.createdAt)),
                _row('设备', record.deviceId ?? '-'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ShadButton(
            width: double.infinity,
            onPressed: () => _reprint(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('重打'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          selectable
              ? SelectableText(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                )
              : Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
