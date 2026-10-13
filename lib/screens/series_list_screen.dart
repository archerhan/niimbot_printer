import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/product_series.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';
import 'series_edit_screen.dart';

/// 产品系列管理：新增 / 编辑 / 删除 / 切换当前系列。
class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  Future<void> _switchTo(ProductSeries series) async {
    final controller = AppScope.of(context);
    await controller.settings.switchSeries(series.id);
    if (!mounted) return;
    setState(() {});
    ShadToaster.of(context).show(
      ShadToast(
        title: Text('已切换到「${series.displayName}」'),
        description: const Text('首页的产品编号已按该系列更新'),
      ),
    );
  }

  Future<void> _create() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SeriesEditScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(ProductSeries series) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeriesEditScreen(series: series),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(ProductSeries series) async {
    final controller = AppScope.of(context);

    if (series.id == controller.settings.currentSeriesId) {
      await showAlert(
        context,
        title: '无法删除当前系列',
        message: '「${series.displayName}」正在使用中。\n'
            '请先切换到其它产品系列，再删除它。',
      );
      return;
    }

    final confirmed = await showConfirm(
      context,
      title: '删除产品系列',
      message: '确定删除「${series.displayName}」吗？\n'
          '该系列的前缀和序号会被删除，已打印的历史记录会保留。',
      confirmText: '删除',
      destructive: true,
    );
    if (!confirmed) return;

    await controller.settings.deleteSeries(series.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final seriesList = controller.settings.seriesList;
    final currentId = controller.settings.currentSeriesId;

    return Scaffold(
      appBar: AppBar(title: const Text('产品系列')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '每个系列有一套前缀（A / B / C）和自己的序号。'
            '切换后首页的产品编号会跟着变，但各系列的序号互不影响、不会重置。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          for (final series in seriesList) ...[
            _seriesCard(series, isCurrent: series.id == currentId),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          ShadButton(
            width: double.infinity,
            height: 48,
            onPressed: _create,
            child: const Text('新增产品系列'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _seriesCard(ProductSeries series, {required bool isCurrent}) {
    return ShadCard(
      title: Row(
        children: [
          Expanded(child: Text(series.displayName)),
          if (isCurrent) const ShadBadge(child: Text('当前使用')),
        ],
      ),
      description: Text(
        '前缀：${_prefixPreview(series)}　'
        '序号：${series.serialNumber.toString().padLeft(4, '0')}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrent)
            ShadButton(
              onPressed: () => _switchTo(series),
              child: const Text('切换到此系列'),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ShadButton.outline(
                onPressed: () => _edit(series),
                child: const Text('编辑'),
              ),
              ShadButton.outline(
                onPressed: () => _delete(series),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _prefixPreview(ProductSeries series) {
    final parts = <String>[
      if (series.prefixA.isNotEmpty) series.prefixA,
      if (series.prefixB.isNotEmpty) series.prefixB,
      if (series.prefixC.isNotEmpty) series.prefixC,
    ];
    return parts.isEmpty ? '（空）' : parts.join(' + ');
  }
}
