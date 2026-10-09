import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/label_job.dart';
import '../models/print_record.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PrintRecord> _records = const <PrintRecord>[];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final controller = AppScope.of(context);
    final records = await controller.history.recent(limit: 200);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _reprint(PrintRecord record) async {
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
    if (!mounted) return;
    if (outcome.success) {
      await showAlert(
        context,
        title: '重打成功',
        message: '产品编号：${record.productCode}',
      );
    } else {
      await showAlert(
        context,
        title: '重打失败',
        message: '${outcome.error}',
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('打印历史'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(child: Text('暂无打印记录'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _recordCard(_records[index]),
                ),
    );
  }

  Widget _recordCard(PrintRecord record) {
    final statusColor = record.success ? Colors.green : Colors.red;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => HistoryDetailScreen(record: record),
          ),
        );
        await _load();
      },
      child: ShadCard(
        title: Row(
          children: [
            Expanded(child: Text(record.productCode)),
            if (record.isReprint)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: ShadBadge(child: Text('重打')),
              ),
          ],
        ),
        description: Text(
          '配件：${record.accessoryCode}\n'
          '序号：${record.serial.toString().padLeft(4, '0')}\n'
          '时间：${_formatTime(record.createdAt)}',
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              record.success ? '打印成功' : '打印失败',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                ShadButton.outline(
                  onPressed: () => _reprint(record),
                  child: const Text('重打'),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}
