import 'package:flutter/material.dart' hide FormField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class FormFieldEditPage extends ConsumerStatefulWidget {
  final int taskId;
  const FormFieldEditPage({super.key, required this.taskId});

  @override
  ConsumerState<FormFieldEditPage> createState() => _FormFieldEditPageState();
}

class _FieldEditor {
  int id;
  String label;
  String exportHeader;
  String fieldType;
  bool isRequired;
  bool isConfidential;
  bool hasData;
  String options;
  _FieldEditor({
    this.id = 0,
    this.label = '',
    this.exportHeader = '',
    this.fieldType = 'text',
    this.isRequired = false,
    this.isConfidential = false,
    this.hasData = false,
    this.options = '',
  });
}

class _FormFieldEditPageState extends ConsumerState<FormFieldEditPage> {
  final List<_FieldEditor> _fields = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(apiProvider).listFields(widget.taskId);
      _fields
        ..clear()
        ..addAll(list.map((e) {
          final f = FormField.fromJson(e as Map<String, dynamic>);
          return _FieldEditor(
            id: f.id,
            label: f.label,
            exportHeader: f.exportHeader,
            fieldType: f.fieldType,
            isRequired: f.isRequired,
            isConfidential: f.isConfidential,
            hasData: f.hasData,
            options: f.options,
          );
        }));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addField() {
    setState(() => _fields.add(_FieldEditor()));
  }

  void _removeField(int i) => setState(() => _fields.removeAt(i));

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _fields.length) return;
    final tmp = _fields[i];
    _fields[i] = _fields[j];
    _fields[j] = tmp;
    setState(() {});
  }

  Future<void> _save() async {
    for (final f in _fields) {
      if (f.label.trim().isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('存在题目显示名为空')));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final payload = _fields
          .asMap()
          .entries
          .map((e) => {
                'id': e.value.id,
                'label': e.value.label.trim(),
                'export_header': e.value.exportHeader.trim(),
                'field_type': e.value.fieldType,
                'is_required': e.value.isRequired,
                'is_confidential': e.value.isConfidential,
                'options': e.value.fieldType == 'select' ? e.value.options : '',
                'sort_order': e.key,
              })
          .toList();
      await ref.read(apiProvider).saveFields(widget.taskId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存成功')));
        context.go('/admin/tasks/${widget.taskId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin/tasks/${widget.taskId}')),
        title: const Text('表单字段配置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fields.isEmpty
              ? _empty(cs)
              : ReorderableListView.builder(
                  padding: EdgeInsets.all(m3e.spacing.md),
                  buildDefaultDragHandles: false,
                  itemCount: _fields.length,
                  onReorder: (oldI, newI) {
                    setState(() {
                      if (newI > oldI) newI--;
                      final item = _fields.removeAt(oldI);
                      _fields.insert(newI, item);
                    });
                  },
                  itemBuilder: (context, i) => _fieldCard(i, m3e, cs),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addField,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _empty(ColorScheme cs) => Center(
        child: Text('暂无字段，点击右下角 + 添加',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );

  Widget _fieldCard(int i, M3EThemeData m3e, ColorScheme cs) {
    final f = _fields[i];
    return Card(
      key: ValueKey('field_$i'),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: m3e.shapes.large,
      margin: EdgeInsets.only(bottom: m3e.spacing.sm),
      child: Padding(
        padding: EdgeInsets.all(m3e.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('字段 ${i + 1}', style: m3e.typography.labelLarge),
                const Spacer(),
                IconButton(
                  tooltip: '上移',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () => _move(i, -1),
                ),
                IconButton(
                  tooltip: '下移',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: () => _move(i, 1),
                ),
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: f.hasData ? cs.outline : cs.error),
                  onPressed: f.hasData ? null : () => _removeField(i),
                ),
              ],
            ),
            SizedBox(height: m3e.spacing.sm),
            // 显示名（学生看到的题目）
            TextField(
              decoration: InputDecoration(
                labelText: '显示名（学生看到的题目）*',
                hintText: '如：你现在住哪里？',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: cs.surfaceContainer,
              ),
              onChanged: (v) => f.label = v,
              controller: TextEditingController(text: f.label),
            ),
            SizedBox(height: m3e.spacing.sm),
            // 导出列名（双轨制核心）
            TextField(
              decoration: InputDecoration(
                labelText: '导出列名（Excel 表头，留空则用显示名）',
                hintText: '如：现居住地（详细到门牌号）',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: cs.surfaceContainer,
                helperText: '最终 Excel 第一行表头，留空时自动使用显示名',
              ),
              onChanged: (v) => f.exportHeader = v,
              controller: TextEditingController(text: f.exportHeader),
            ),
            SizedBox(height: m3e.spacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                    ),
                    value: f.fieldType,
                    items: const [
                      DropdownMenuItem(value: 'text', child: Text('文本')),
                      DropdownMenuItem(value: 'number', child: Text('数字')),
                      DropdownMenuItem(value: 'date', child: Text('日期')),
                      DropdownMenuItem(value: 'select', child: Text('下拉选择')),
                    ],
                    onChanged: (v) => setState(() => f.fieldType = v ?? 'text'),
                  ),
                ),
                SizedBox(width: m3e.spacing.md),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('必填'),
                    value: f.isRequired,
                    onChanged: (v) => setState(() => f.isRequired = v),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('保密'),
              subtitle: const Text('学生再次编辑时该字段以掩码显示，输入新值才覆盖'),
              value: f.isConfidential,
              onChanged: (v) => setState(() => f.isConfidential = v),
            ),
            if (f.fieldType == 'select') ...[
              SizedBox(height: m3e.spacing.sm),
              TextField(
                decoration: InputDecoration(
                  labelText: '选项（逗号分隔）',
                  hintText: '如：校内,校外',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cs.surfaceContainer,
                ),
                onChanged: (v) => f.options = v,
                controller: TextEditingController(text: f.options),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
