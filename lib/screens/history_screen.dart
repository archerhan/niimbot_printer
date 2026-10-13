import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/label_job.dart';
import '../models/print_record.dart';
import '../services/history_repository.dart';
import '../state/app_scope.dart';
import '../widgets/app_dialogs.dart';
import 'history_detail_screen.dart';

/// 打印历史：按天分组、筛选、搜索、多选删除、重打。
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _pageSize = 30;

  final TextEditingController _search = TextEditingController();

  String? _seriesId;
  String? _seriesLabel;
  String? _month;
  String _keyword = '';

  List<PrintRecord> _records = const <PrintRecord>[];
  List<SeriesOption> _seriesOptions = const <SeriesOption>[];
  List<String> _months = const <String>[];
  int _total = 0;
  bool _hasMore = false;

  bool _loading = true;
  bool _busy = false;

  final Set<int> _selected = <int>{};
  bool _selectionMode = false;

  bool get _hasFilter =>
      _seriesId != null || _month != null || _keyword.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 查询与刷新

  (DateTime?, DateTime?) get _monthRange {
    final month = _month;
    if (month == null) return (null, null);
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final mon = int.parse(parts[1]);
    return (DateTime(year, mon, 1), DateTime(year, mon + 1, 1));
  }

  Future<void> _reload() async {
    final controller = AppScope.of(context);
    final (start, end) = _monthRange;

    setState(() {
      _loading = true;
      _selected.clear();
      _selectionMode = false;
    });

    final options = await controller.history.seriesOptions();
    final months = await controller.history.availableMonths();
    final records = await controller.history.search(
      seriesId: _seriesId,
      monthStart: start,
      monthEnd: end,
      keyword: _keyword,
      limit: _pageSize,
    );
    final total = await controller.history.countMatching(
      seriesId: _seriesId,
      monthStart: start,
      monthEnd: end,
      keyword: _keyword,
    );

    if (!mounted) return;
    setState(() {
      _seriesOptions = options;
      _months = months;
      _records = records;
      _total = total;
      _hasMore = records.length < total;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_hasMore == false || _busy) return;
    final controller = AppScope.of(context);
    final (start, end) = _monthRange;

    setState(() => _busy = true);
    final more = await controller.history.search(
      seriesId: _seriesId,
      monthStart: start,
      monthEnd: end,
      keyword: _keyword,
      limit: _pageSize,
      offset: _records.length,
    );
    if (!mounted) return;
    setState(() {
      _records = <PrintRecord>[..._records, ...more];
      _hasMore = _records.length < _total;
      _busy = false;
    });
  }

  // -------------------------------------------------------------- 筛选与搜索

  Future<void> _pickSeries() async {
    final options = <String>['全部系列'];
    final ids = <String?>[null];
    for (final option in _seriesOptions) {
      options.add(option.name.isEmpty ? '（未命名系列）' : option.name);
      ids.add(option.id);
    }
    final index = await _pickOption('按产品系列筛选', options);
    if (index == null) return;
    setState(() {
      _seriesId = ids[index];
      _seriesLabel = index == 0 ? null : options[index];
    });
    await _reload();
  }

  Future<void> _pickMonth() async {
    final options = <String>['全部月份', ..._months];
    final index = await _pickOption('按月份筛选', options);
    if (index == null) return;
    setState(() => _month = index == 0 ? null : options[index]);
    await _reload();
  }

  Future<int?> _pickOption(String title, List<String> options) {
    return showShadDialog<int>(
      context: context,
      builder: (ctx) => ShadDialog(
        title: Text(title),
        child: SizedBox(
          width: 280,
          height: 280,
          // ShadDialog 不是 Material 组件，ListTile 需要 Material 祖先。
          child: Material(
            type: MaterialType.transparency,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, index) => ListTile(
                title: Text(
                  options[index],
                  style: const TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.of(ctx).pop(index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 删除

  void _toggleSelection(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _selectAll() async {
    final controller = AppScope.of(context);
    final (start, end) = _monthRange;
    // 全选只作用于当前筛选与搜索命中的结果集。
    final ids = await controller.history.searchIds(
      seriesId: _seriesId,
      monthStart: start,
      monthEnd: end,
      keyword: _keyword,
    );
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(ids);
      _selectionMode = true;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final confirmed = await showConfirm(
      context,
      title: '删除所选记录',
      message: '确定删除选中的 $count 条记录吗？\n'
          '删除后列表里不再显示，但跳号判断和重复配件码提示仍会参考这些记录。',
      confirmText: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;

    final controller = AppScope.of(context);
    await controller.history.softDelete(_selected.toList());
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    await _reload();
  }

  // ------------------------------------------------------------------ 重打

  Future<void> _reprint(PrintRecord record) async {
    final controller = AppScope.of(context);
    if (!controller.isConnected) {
      await showAlert(
        context,
        title: '打印机未连接',
        message: '请先连接打印机。',
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
      seriesId: record.seriesId,
      seriesName: record.seriesName,
    );
    final outcome = await controller.printService.print(job);
    if (!mounted) return;
    await showAlert(
      context,
      title: outcome.success ? '重打成功' : '重打失败',
      message: outcome.success
          ? '产品编号：${record.productCode}'
          : '${outcome.error}',
    );
    await _reload();
  }

  // ------------------------------------------------------------------ 界面

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '已选 ${_selected.length} 条' : '打印历史'),
        leading: _selectionMode
            ? IconButton(
                tooltip: '退出选择',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selected.clear();
                  _selectionMode = false;
                }),
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: const Text('全选'),
            ),
            TextButton(
              onPressed: _selected.isEmpty ? null : _deleteSelected,
              child: const Text('删除'),
            ),
          ] else ...[
            IconButton(
              tooltip: '选择多条记录',
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _selectionMode = true),
            ),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShadInput(
            controller: _search,
            placeholder: const Text('搜索产品编号，例如 0012'),
            onSubmitted: (value) {
              setState(() => _keyword = value.trim());
              _reload();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: _pickSeries,
                  child: Text(
                    '系列：${_seriesLabel ?? '全部'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  onPressed: _pickMonth,
                  child: Text('月份：${_month ?? '全部'}'),
                ),
              ),
              if (_hasFilter) ...[
                const SizedBox(width: 8),
                ShadButton.outline(
                  onPressed: () {
                    _search.clear();
                    setState(() {
                      _seriesId = null;
                      _seriesLabel = null;
                      _month = null;
                      _keyword = '';
                    });
                    _reload();
                  },
                  child: const Text('重置'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '共 $_total 条记录'
            '${_selectionMode ? '；长按或勾选可多选' : '；长按记录可进入多选'}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(_hasFilter ? '没有符合条件的记录' : '暂无打印记录'),
      );
    }

    final items = <Widget>[];
    String? lastDay;
    for (final record in _records) {
      final day = _dayKey(record.createdAt);
      if (day != lastDay) {
        lastDay = day;
        items.add(_dayHeader(record.createdAt));
      }
      items.add(_recordCard(record));
      items.add(const SizedBox(height: 12));
    }
    if (_hasMore) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: ShadButton.outline(
              onPressed: _busy ? null : _loadMore,
              child: Text(_busy ? '加载中…' : '加载更多'),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: items,
    );
  }

  Widget _dayHeader(DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        _dayLabel(time),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _recordCard(PrintRecord record) {
    final selected = _selected.contains(record.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(record.id!);
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => HistoryDetailScreen(record: record),
          ),
        );
      },
      onLongPress: () => _toggleSelection(record.id!),
      child: ShadCard(
        title: Row(
          children: [
            if (_selectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                ),
              ),
            Expanded(child: Text(record.productCode)),
            if (record.isReprint)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: ShadBadge(child: Text('重打')),
              ),
          ],
        ),
        description: Text(
          '系列：${record.seriesName.isEmpty ? '—' : record.seriesName}\n'
          '配件：${record.accessoryCode}\n'
          '序号：${record.serial.toString().padLeft(4, '0')}\n'
          '时间：${_formatTime(record.createdAt)}',
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              record.success ? '打印成功' : '打印失败',
              style: TextStyle(
                color: record.success ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_selectionMode)
              ShadButton.outline(
                onPressed: () => _reprint(record),
                child: const Text('重打'),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 工具

  String _dayKey(DateTime time) =>
      '${time.year}-${time.month}-${time.day}';

  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    final date = '${time.year}-${_two(time.month)}-${_two(time.day)}';
    if (diff == 0) return '$date（今天）';
    if (diff == 1) return '$date（昨天）';
    return date;
  }

  String _formatTime(DateTime time) =>
      '${_two(time.hour)}:${_two(time.minute)}';

  String _two(int value) => value.toString().padLeft(2, '0');
}
