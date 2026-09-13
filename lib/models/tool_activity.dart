class ToolActivity {
  const ToolActivity({
    required this.eventId,
    required this.chainId,
    required this.characterId,
    required this.name,
    required this.status,
  });
  final String eventId;
  final String chainId;
  final String characterId;
  final String name;
  final String status;

  static ToolActivity? tryParse(Object? value) {
    if (value is! Map || value['source'] != 'reality') return null;
    String field(String key) =>
        value[key] is String ? (value[key] as String).trim() : '';
    if (field('event_id').isEmpty ||
        field('tool_name').isEmpty ||
        field('char_id').isEmpty) {
      return null;
    }
    return ToolActivity(
      eventId: field('event_id'),
      chainId: field('chain_id'),
      characterId: field('char_id'),
      name: field('tool_name'),
      status: field('status'),
    );
  }

  bool sameChain(ToolActivity? other) =>
      other != null &&
      chainId.isNotEmpty &&
      chainId == other.chainId &&
      characterId == other.characterId;
}
