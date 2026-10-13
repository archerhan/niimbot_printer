import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/code_generator.dart';
import '../core/series_rules.dart';
import '../models/product_series.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';

/// 新增或编辑一个产品系列。
class SeriesEditScreen extends StatefulWidget {
  const SeriesEditScreen({super.key, this.series});

  /// 为空表示新增。
  final ProductSeries? series;

  @override
  State<SeriesEditScreen> createState() => _SeriesEditScreenState();
}

class _SeriesEditScreenState extends State<SeriesEditScreen> {
  static const SeriesRules _rules = SeriesRules();
  static const CodeGenerator _generator = CodeGenerator();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _prefixA = TextEditingController();
  final TextEditingController _prefixB = TextEditingController();
  final TextEditingController _prefixC = TextEditingController();
  bool _initialized = false;

  bool get _isNew => widget.series == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final series = widget.series;
    if (series != null) {
      _name.text = series.name;
      _prefixA.text = series.prefixA;
      _prefixB.text = series.prefixB;
      _prefixC.text = series.prefixC;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _prefixA,
      _prefixB,
      _prefixC,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final existing = widget.series;

    final candidate = ProductSeries(
      id: existing?.id ?? 's${DateTime.now().microsecondsSinceEpoch}',
      createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      name: _name.text.trim(),
      prefixA: _prefixA.text.trim(),
      prefixB: _prefixB.text.trim(),
      prefixC: _prefixC.text.trim(),
      // 序号不在这里修改，保持不变；新系列从 1 开始。
      serialNumber: existing?.serialNumber ?? 1,
    );

    final others = controller.settings.seriesList;
    final error = _rules.validate(candidate, others);
    if (error != null) {
      await showAlert(context, title: '无法保存', message: error);
      return;
    }

    final conflict = _rules.conflictWarning(candidate, others);
    if (conflict != null && mounted) {
      final proceed = await showConfirm(
        context,
        title: '前缀与其它系列重复',
        message: '$conflict\n仍要保存吗？',
        confirmText: '仍然保存',
      );
      if (!proceed) return;
    }

    // 修改当前系列的前缀时，展示拼接结果让用户确认。
    final isCurrent = existing != null &&
        existing.id == controller.settings.currentSeriesId;
    final prefixChanged = existing != null &&
        (existing.prefixA != candidate.prefixA ||
            existing.prefixB != candidate.prefixB ||
            existing.prefixC != candidate.prefixC);
    if (isCurrent && prefixChanged && mounted) {
      final serialText = _generator.formatSerial(candidate.serialNumber);
      final productCode = _generator.buildProductCode(
        prefixA: candidate.prefixA,
        prefixB: candidate.prefixB,
        prefixC: candidate.prefixC,
        serial: candidate.serialNumber,
      );
      final lines = _generator.buildLabelLines(
        prefixA: candidate.prefixA,
        prefixB: candidate.prefixB,
        prefixC: candidate.prefixC,
        serial: candidate.serialNumber,
      );
      final proceed = await showConfirm(
        context,
        title: '确认新的产品编号',
        message: '修改后，下一次打印的产品编号将是：\n\n'
            '$productCode\n\n'
            '标签上的三行文字：\n'
            '${lines.map((line) => line.isEmpty ? '（空）' : line).join('\n')}\n\n'
            '序号保持 $serialText 不变，不会重置。',
        confirmText: '确认修改',
      );
      if (!proceed) return;
    }

    if (_isNew) {
      await controller.settings.addSeries(candidate);
    } else {
      await controller.settings.updateSeries(candidate);
    }

    if (!mounted) return;
    await showAlert(context, title: '已保存');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? '新增产品系列' : '编辑产品系列';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShadCard(
            title: const Text('产品名称'),
            description: const Text(
              '给这个系列起个名字，方便在列表里区分，不会打印到标签上。\n'
              '可以不填；不填时列表会显示前缀本身。',
            ),
            child: _field('产品名称（选填）', _name, helper: '例如：ADM 系列'),
          ),
          const SizedBox(height: 16),
          ShadCard(
            title: const Text('前缀'),
            description: const Text(
              '三段前缀会按顺序拼在产品编号最前面，再跟上序号。\n'
              '可以留空某一段，但至少填一段。',
            ),
            child: Column(
              children: [
                _field('前缀 A', _prefixA, helper: '例如：ADM32672805'),
                _field('前缀 B', _prefixB, helper: '例如：CTX'),
                _field('前缀 C', _prefixC, helper: '例如：6O6'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '注意：前缀里不能有空格，也不能有 # @ ! 这三个符号（会破坏二维码格式）。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ShadButton(
            width: double.infinity,
            height: 48,
            onPressed: _save,
            child: Text(_isNew ? '创建系列' : '保存修改'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          ShadInput(controller: controller),
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
