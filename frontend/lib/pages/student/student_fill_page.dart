import 'package:flutter/material.dart' hide FormField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/m3e_theme.dart';

class StudentFillPage extends ConsumerStatefulWidget {
  final int taskId;
  const StudentFillPage({super.key, required this.taskId});

  @override
  ConsumerState<StudentFillPage> createState() => _StudentFillPageState();
}

class _StudentFillPageState extends ConsumerState<StudentFillPage> {
  Task? _task;
  List<FormField> _fields = [];
  final Map<String, dynamic> _values = {};
  bool _loading = true;
  bool _saving = false;
  bool _loadedExisting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final cfg = await api.getFormConfig(widget.taskId);
      _task = Task.fromJson(cfg['task'] as Map<String, dynamic>);
      _fields = (cfg['fields'] as List)
          .map((e) => FormField.fromJson(e as Map<String, dynamic>))
          .toList();

      // 加载已有提交
      final existing = await api.getMySubmission();
      if (existing['data'] != null) {
        final data = Map<String, dynamic>.from(existing['data'] as Map);
        for (final f in _fields) {
          _values[f.id.toString()] = data[f.id.toString()];
        }
        _loadedExisting = true;
      }
    } catch (_) {
      // 忽略
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    // 必填校验
    for (final f in _fields) {
      if (f.isRequired) {
        final v = _values[f.id.toString()];
        if (v == null || (v is String && v.trim().isEmpty)) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('「${f.label}」为必填项')));
          return;
        }
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).submitForm(_values);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('提交成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('提交失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m3e = M3ETheme.of(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/student/tasks')),
        title: Text(_task?.title ?? '填报'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fields.isEmpty
              ? Center(
                  child: Text('该任务暂未配置字段',
                      style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView(
                  padding: EdgeInsets.all(m3e.spacing.md),
                  children: [
                    // 姓名锁定区
                    _buildLockedNameCard(auth.displayName ?? '同学', m3e, cs),
                    if (_loadedExisting)
                      Padding(
                        padding: EdgeInsets.only(top: m3e.spacing.sm),
                        child: Text('已检测到历史提交，修改后将覆盖原数据',
                            style: m3e.typography.labelSmall.copyWith(color: cs.tertiary)),
                      ),
                    SizedBox(height: m3e.spacing.lg),
                    ..._fields.map((f) => _buildField(f, m3e, cs)),
                    SizedBox(height: m3e.spacing.lg),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(_saving ? '提交中...' : '提交'),
                    ),
                  ],
                ),
    );
  }

  /// 姓名锁定区：使用 Shapes & Colors Tokens（大圆角 + surfaceContainerLow 层级）
  Widget _buildLockedNameCard(String name, M3EThemeData m3e, ColorScheme cs) {
    return Card(
      shape: m3e.shapes.extraLarge,
      color: cs.surfaceContainerLow,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(m3e.spacing.md),
        child: Row(
          children: [
            Icon(Icons.verified_user, color: cs.primary),
            SizedBox(width: m3e.spacing.sm),
            Text(name, style: m3e.typography.titleMedium),
            const Spacer(),
            Text('已验证', style: m3e.typography.labelSmall.copyWith(color: cs.primary)),
          ],
        ),
      ),
    );
  }

  /// 动态表单渲染：使用 Spacing & Typography Tokens
  Widget _buildField(FormField f, M3EThemeData m3e, ColorScheme cs) {
    final key = f.id.toString();
    return Padding(
      padding: EdgeInsets.only(bottom: m3e.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                f.isRequired ? '${f.label} *' : f.label,
                style: m3e.typography.labelLarge,
              ),
              if (f.isConfidential) ...[
                SizedBox(width: m3e.spacing.xs),
                Icon(Icons.shield_outlined, size: 16, color: cs.tertiary),
              ],
            ],
          ),
          SizedBox(height: m3e.spacing.xs),
          _fieldInput(f, key, m3e, cs),
        ],
      ),
    );
  }

  Widget _fieldInput(FormField f, String key, M3EThemeData m3e, ColorScheme cs) {
    final isMasked = _values[key]?.toString() == '******';
    final controller = TextEditingController(
        text: isMasked ? '******' : (_values[key]?.toString() ?? ''));
    controller.selection =
        TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    void setVal(String v) => _values[key] = v;
    // 保密字段：输入时完整显示，离开后再次进入显示掩码 ******，点击清空以输入新值
    final maskedHint = '保密信息已隐藏，输入新值以覆盖';

    void clearMask() {
      if (isMasked) setState(() => _values[key] = null);
    }

    switch (f.fieldType) {
      case 'number':
        return TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _inputDeco(isMasked ? maskedHint : '请输入${f.label}', cs, isMasked: isMasked),
          onTap: clearMask,
          onChanged: setVal,
        );
      case 'date':
        return TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          decoration: _inputDeco(isMasked ? maskedHint : 'YYYY-MM-DD', cs, isMasked: isMasked),
          onTap: clearMask,
          onChanged: setVal,
        );
      case 'select':
        final options = f.optionList;
        return DropdownButtonFormField<String>(
          value: isMasked ? null : _values[key]?.toString(),
          decoration: _inputDeco('请选择', cs),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _values[key] = v),
        );
      default:
        return TextField(
          controller: controller,
          decoration: _inputDeco(isMasked ? maskedHint : '请输入${f.label}', cs, isMasked: isMasked),
          onTap: clearMask,
          onChanged: setVal,
        );
    }
  }

  InputDecoration _inputDeco(String hint, ColorScheme cs, {bool isMasked = false}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isMasked ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        border: const OutlineInputBorder(),
      );
}
