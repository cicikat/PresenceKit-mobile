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
