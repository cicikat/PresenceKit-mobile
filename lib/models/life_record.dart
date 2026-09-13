import 'dart:convert';

/// Explicit user import into the existing editable fields, never server evidence.
class LifeRecognitionImport {
  const LifeRecognitionImport({this.title, required this.note, this.items});
  final String? title;
  final String note;
  final List<Map<String, dynamic>>? items;

  factory LifeRecognitionImport.parse(String source) {
    final text = source.trim();
    final unfenced = text
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    dynamic decoded;
    try {
      decoded = jsonDecode(unfenced);
    } catch (_) {
      /* Plain description. */
    }
    if (decoded is Map<String, dynamic>) {
      final rest = Map<String, dynamic>.from(decoded);
      final title = rest['title'] is String
          ? rest.remove('title') as String
          : null;
      final note = rest['note'] is String ? rest.remove('note') as String : '';
      final rawItems = rest['items'];
      List<Map<String, dynamic>>? items;
      if (rawItems is List &&
          rawItems.length <= 100 &&
          rawItems.every(
            (v) =>
                v is Map<String, dynamic> &&
                v['name'] is String &&
                (v['name'] as String).trim().isNotEmpty &&
                v.values.every(
                  (value) => value == null || value is String || value is num,
                ),
          )) {
        items = rawItems
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        rest.remove('items');
      }
      return LifeRecognitionImport(
        title: title,
        note: [
          if (note.isNotEmpty) note,
          if (rest.isNotEmpty) const JsonEncoder.withIndent('  ').convert(rest),
        ].join('\n'),
        items: items,
      );
    }
    String? title;
    final notes = <String>[];
    for (final line in text.split('\n')) {
      final match = RegExp(
        r'^\s*(标题|title|备注|note)\s*[:：]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) {
        notes.add(line);
        continue;
      }
      if (match[1] == '标题' || match[1]!.toLowerCase() == 'title') {
        if (title != null) notes.add(title);
        title = match[2];
      } else {
        notes.add(match[2]!);
      }
    }
    return LifeRecognitionImport(title: title, note: notes.join('\n').trim());
  }
}

class LifeRecord {
  LifeRecord(this.data);
  final Map<String, dynamic> data;

  String get id => data['id'] as String? ?? '';
  String get category => data['category'] as String? ?? 'diet';
  String get date => data['occurred_on'] as String? ?? '';
  String get title => data['title'] as String? ?? '';
  String get note => data['note'] as String? ?? '';
  String get recognitionDescription =>
      data['recognition_description'] as String? ?? '';
  int get revision => (data['revision'] as num?)?.toInt() ?? 0;
  String get recognition => data['recognition_status'] as String? ?? 'pending';
  bool get deleted => data['local_deleted'] == true;
  List<Map<String, dynamic>> get items => (data['items'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Map<String, dynamic>> get operations =>
      (data['local_operations'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  bool get pending => operations.isNotEmpty;
  bool get conflict => operations.any((e) => e['state'] == 'conflict');
  bool get failed =>
      operations.any((e) => e['state'] == 'failed' || e['state'] == 'rejected');
  String get searchText =>
      '$title $note $recognitionDescription ${items.map((e) => e['name']).join(' ')}'
          .toLowerCase();

  static String day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
