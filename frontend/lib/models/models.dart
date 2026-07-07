class Task {
  final int id;
  final String title;
  final String description;
  final String status;
  final DateTime? createdAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'open',
    this.createdAt,
  });

  bool get isOpen => status == 'open';

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String,
        description: (json['description'] ?? '') as String,
        status: (json['status'] ?? 'open') as String,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

class FormField {
  final int id;
  final int taskId;
  final String label;
  final String exportHeader;
  final String fieldType; // text / number / date / select
  final bool isRequired;
  final bool isConfidential; // 是否保密（学生再次编辑时脱敏）
  final String options; // JSON 字符串
  final int sortOrder;
  final bool hasData; // 该字段是否已有提交数据（后端计算，前端只读）

  FormField({
    required this.id,
    required this.taskId,
    required this.label,
    this.exportHeader = '',
    this.fieldType = 'text',
    this.isRequired = false,
    this.isConfidential = false,
    this.options = '',
    this.sortOrder = 0,
    this.hasData = false,
  });

  /// 导出列名：优先 export_header，为空降级 label（双轨制核心）
  String get resolvedExportHeader =>
      exportHeader.trim().isEmpty ? label : exportHeader;

  /// select 选项解析
  List<String> get optionList {
    if (options.trim().isEmpty) return [];
    // 容忍 ["a","b"] 或 a,b
    final raw = options.trim();
    if (raw.startsWith('[')) {
      try {
        final list = (raw
                .substring(1, raw.length - 1)
                .split(',')
                .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((e) => e.isNotEmpty))
            .toList();
        return list;
      } catch (_) {
        return [];
      }
    }
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  factory FormField.fromJson(Map<String, dynamic> json) => FormField(
        id: json['id'] as int,
        taskId: (json['task_id'] ?? 0) as int,
        label: json['label'] as String,
        exportHeader: (json['export_header'] ?? '') as String,
        fieldType: (json['field_type'] ?? 'text') as String,
        isRequired: (json['is_required'] ?? false) as bool,
        isConfidential: (json['is_confidential'] ?? false) as bool,
        options: (json['options'] ?? '') as String,
        sortOrder: (json['sort_order'] ?? 0) as int,
        hasData: (json['has_data'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'label': label,
        'export_header': exportHeader,
        'field_type': fieldType,
        'is_required': isRequired,
        'is_confidential': isConfidential,
        'options': options,
        'sort_order': sortOrder,
      };
}

class Student {
  final int id;
  final int taskId;
  final String studentNo;
  final String name;

  Student({
    required this.id,
    required this.taskId,
    required this.studentNo,
    required this.name,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as int,
        taskId: (json['task_id'] ?? 0) as int,
        studentNo: (json['student_no'] ?? '') as String,
        name: (json['name'] ?? '') as String,
      );
}

class SubmissionItem {
  final Student student;
  final bool submitted;
  final Map<String, dynamic>? data;

  SubmissionItem({
    required this.student,
    required this.submitted,
    this.data,
  });

  factory SubmissionItem.fromJson(Map<String, dynamic> json) => SubmissionItem(
        student: Student.fromJson(json['student'] as Map<String, dynamic>),
        submitted: (json['submitted'] ?? false) as bool,
        data: json['data'] != null
            ? Map<String, dynamic>.from(json['data'] as Map)
            : null,
      );
}
