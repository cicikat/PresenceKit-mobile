import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/life_records_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/life_record.dart';
import 'common_widgets.dart';

String lifeCategory(AppLocalizations l, String value) => switch (value) {
  'diet' => l.lifeDiet,
  'bill' => l.lifeBill,
  'cart' => l.lifeCart,
  _ => l.lifeAll,
};

String lifeStatus(AppLocalizations l, String? value) => switch (value) {
  'ready' => l.lifeConnected,
  'auth' || 'http_401' => l.lifeAuth,
  'forbidden' || 'http_403' => l.lifeForbidden,
  'unsupported' || 'http_404' || 'http_501' => l.lifeNotIntegrated,
  'disabled' => l.lifeDisabled,
  'setup_required' || 'origin_untrusted' => l.lifeSetup,
  'account_changed' => l.lifeAccountChanged,
  'conflict' => l.lifeConflict,
  'stale_revision' => l.lifeStaleEditor,
  'conflict_unavailable' => l.lifeRejected,
  'queue_full' => l.lifeQueueFull,
  'image_too_large' => l.lifeImageTooLarge,
  'unsupported_platform' => l.lifeAndroidOnly,
  'rejected' || 'invalid_response' => l.lifeRejected,
  'rate_limited' || 'http_429' => l.lifeRateLimited,
  'storage_error' => l.lifeStorageError,
  'offline' => l.lifeOffline,
  'foreground_only' => l.lifeForegroundOnly,
  _ => l.lifeWaiting,
};

class LifeRecordsPage extends StatefulWidget {
  const LifeRecordsPage({
    super.key,
    required this.c,
    required this.controller,
    required this.onBack,
  });
  final YxPalette c;
  final LifeRecordsController controller;
  final VoidCallback onBack;
  @override
  State<LifeRecordsPage> createState() => _LifeRecordsPageState();
}

class _LifeRecordsPageState extends State<LifeRecordsPage> {
  LifeRecordsController get controller => widget.controller;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    if (controller.available) {
      unawaited(controller.search());
      unawaited(_recover());
    }
  }

  Future<void> _recover() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.files?.isNotEmpty == true && mounted) {
        await _openFile(lost.files!.first, controller.realm);
      } else if (lost.exception != null && mounted) {
        _message(context.l10n.lifeCaptureFailed);
      }
    } catch (_) {
      if (mounted) _message(context.l10n.lifeCaptureFailed);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pick(ImageSource source) async {
    final expected = controller.realm;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (image != null && mounted) await _openFile(image, expected);
    } catch (_) {
      if (mounted) _message(context.l10n.lifeCaptureFailed);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _openFile(XFile file, String expected) async {
    if (await file.length() > 10 * 1024 * 1024) {
      if (mounted) _message(context.l10n.lifeImageTooLarge);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final mime = _imageMime(bytes);
    if (mime == null) {
      _message(context.l10n.lifeImageFormat);
      return;
    }
    await _edit(null, image: bytes, mime: mime, expected: expected);
  }

  String? _imageMime(Uint8List bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _edit(
    LifeRecord? record, {
    Uint8List? image,
    String? mime,
    String? expected,
  }) async {
    final realm = expected ?? controller.realm;
    if (record != null) {
      try {
        image = await controller.service.image(
          controller.origin(),
          controller.owner(),
          record.id,
        );
      } catch (_) {
        /* The structured record remains editable without a cached image. */
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LifeRecordEditor(
        controller: controller,
        record: record,
        image: image,
        mime: mime,
        expectedRealm: realm,
      ),
    );
  }

  Future<void> _confirm(LifeRecord record, {bool conflict = false}) async {
    final l = context.l10n;
    final expected = controller.realm;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(conflict ? l.lifeAcceptServer : l.lifeDelete),
        content: Text(conflict ? l.lifeConflictHelp : l.lifeDeleteHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.lifeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.lifeConfirm),
          ),
        ],
      ),
    );
    if (yes == true && controller.realm == expected) {
      if (conflict) {
        await controller.acceptServer(record.id);
      } else {
        await controller.delete(record.id);
      }
    }
  }

  Future<void> _dates() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (dates != null && mounted) {
      controller.filters(
        from: LifeRecord.day(dates.start),
        to: LifeRecord.day(dates.end),
      );
      await controller.search();
    }
  }

  Future<void> _observe() async {
    await controller.observe();
    if (!mounted) return;
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.lifeQueue),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.lifePendingCount(controller.pendingCount)),
              Text(
                lifeStatus(
                  l,
                  controller.error ?? controller.syncState['status'] as String?,
                ),
              ),
              Text(l.lifeBackgroundHelp),
              if (controller.syncState['last_ack'] is num)
                Text(
                  l.lifeLastAck(
                    DateTime.fromMillisecondsSinceEpoch(
                      (controller.syncState['last_ack'] as num).toInt(),
                    ).toLocal().toString(),
                  ),
                ),
              if (controller.observation != null)
                SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(controller.observation),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.lifeClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = context.l10n;
      final records = controller.visible;
      return Column(
        children: [
          PageHeader(
            c: widget.c,
            title: l.lifeTitle,
            eyebrow: l.lifeSubtitle,
            onBack: widget.onBack,
            trailing: l.lifePendingCount(controller.pendingCount),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.lifeIntro),
                const SizedBox(height: 12),
                if (!controller.available) Text(l.lifeAndroidOnly),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: !controller.available || _picking
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(l.lifeCamera),
                    ),
                    OutlinedButton.icon(
                      onPressed: !controller.available || _picking
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l.lifeGallery),
                    ),
                    IconButton(
                      tooltip: l.lifeSync,
                      onPressed: controller.busy || !controller.available
                          ? null
                          : () async {
                              await controller.synchronize(manual: true);
                              await controller.search();
                            },
                      icon: const Icon(Icons.sync),
                    ),
                    IconButton(
                      tooltip: l.lifeQueue,
                      onPressed: !controller.available ? null : _observe,
                      icon: const Icon(Icons.cloud_upload_outlined),
                    ),
                  ],
                ),
                if (controller.busy || controller.querying)
                  const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  lifeStatus(
                    l,
                    controller.error ??
                        controller.syncState['status'] as String?,
                  ),
                ),
                Text(
                  controller.cacheOnly ? l.lifeCacheOnly : l.lifeServerResults,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['', 'diet', 'bill', 'cart']
                      .map(
                        (category) => ChoiceChip(
                          label: Text(lifeCategory(l, category)),
                          selected: controller.category == category,
                          onSelected: (_) {
                            controller.filters(category: category);
                            unawaited(controller.search());
                          },
                        ),
                      )
                      .toList(),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: l.lifeSearch,
                    suffixIcon: IconButton(
                      tooltip: l.lifeSearch,
                      onPressed: controller.querying
                          ? null
                          : () => controller.search(),
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onChanged: (q) => controller.filters(query: q.trim()),
                  onSubmitted: (_) => controller.search(),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _dates,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        controller.from.isEmpty
                            ? l.lifeDateRange
                            : '${controller.from} — ${controller.to}',
                      ),
                    ),
                    if (controller.from.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          controller.filters(from: '', to: '');
                          unawaited(controller.search());
                        },
                        child: Text(l.lifeClearDates),
                      ),
                  ],
                ),
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(l.lifeEmpty),
                  ),
                ...records.map(
                  (record) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record.date} · ${lifeCategory(l, record.category)}',
                          ),
                          Text(
                            record.title.isEmpty
                                ? l.lifeUntitled
                                : record.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            record.deleted
                                ? l.lifeDeleting
                                : record.conflict
                                ? l.lifeConflict
                                : record.failed
                                ? l.lifeRejected
                                : record.pending
                                ? l.lifeQueued
                                : switch (record.recognition) {
                                    'ready' => l.lifeRecognized,
                                    'failed' => l.lifeRecognitionFailed,
                                    _ => l.lifeRecognizing,
                                  },
                          ),
                          if (record.note.isNotEmpty) Text(record.note),
                          ...record.items.map(
                            (item) => Text(
                              [
                                    item['name'],
                                    item['quantity'],
                                    item['unit'],
                                    item['amount'],
                                    item['currency'],
                                  ]
                                  .where(
                                    (v) => v != null && v.toString().isNotEmpty,
                                  )
                                  .join(' · '),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (!record.deleted && !record.conflict)
                                TextButton(
                                  onPressed: () => _edit(record),
                                  child: Text(l.lifeEdit),
                                ),
                              if (!record.deleted && !record.conflict)
                                TextButton(
                                  onPressed: () => _confirm(record),
                                  child: Text(l.lifeDelete),
                                ),
                              if (record.conflict)
                                TextButton(
                                  onPressed: () =>
                                      _confirm(record, conflict: true),
                                  child: Text(l.lifeAcceptServer),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (controller.cursor != null)
                  TextButton(
                    onPressed: controller.querying
                        ? null
                        : () => controller.search(more: true),
                    child: Text(l.lifeMore),
                  ),
                const SizedBox(height: 12),
                Text(
                  l.lifeCartHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  l.lifeBackgroundHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class LifeRecordEditor extends StatefulWidget {
  const LifeRecordEditor({
    super.key,
    required this.controller,
    required this.record,
    required this.image,
    required this.mime,
    required this.expectedRealm,
  });
  final LifeRecordsController controller;
  final LifeRecord? record;
  final Uint8List? image;
  final String? mime;
  final String expectedRealm;
  @override
  State<LifeRecordEditor> createState() => _LifeRecordEditorState();
}

class _LifeRecordEditorState extends State<LifeRecordEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.record?.title,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.record?.note,
  );
  late String _category =
      widget.record?.category ??
      (widget.controller.category.isEmpty
          ? 'diet'
          : widget.controller.category);
  late DateTime _date =
      DateTime.tryParse(widget.record?.date ?? '') ?? DateTime.now();
  late final List<_LifeItemFields> _items =
      widget.record?.items.map(_LifeItemFields.new).toList() ?? [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final record = <String, dynamic>{
      ...?widget.record?.data,
      'title': _title.text.trim(),
      'note': _note.text.trim(),
      'category': _category,
      'occurred_on': LifeRecord.day(_date),
      'captured_at':
          widget.record?.data['captured_at'] ??
          DateTime.now().toUtc().toIso8601String(),
      'recognition_status': widget.record?.recognition ?? 'pending',
      'items': _items.map((row) => row.value).toList(),
      if (widget.mime != null) 'image_mime': widget.mime,
    };
    record['user_edited_fields'] = {
      ...?(widget.record?.data['user_edited_fields'] as List?)?.cast<String>(),
      for (final key in ['title', 'note', 'category', 'occurred_on', 'items'])
        if (jsonEncode(record[key]) != jsonEncode(widget.record?.data[key]) &&
            (key != 'items' || _items.isNotEmpty || widget.record != null) &&
            (key != 'title' && key != 'note' ||
                (record[key] as String).isNotEmpty ||
                widget.record != null))
          key,
    }.toList();
    final ok = await widget.controller.save(
      record,
      widget.record == null ? widget.image : null,
      expectedRealm: widget.expectedRealm,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.record == null ? l.lifeAdd : l.lifeEdit),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.image != null)
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Image.memory(
                        widget.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Text(l.lifeImageFormat),
                      ),
                    ),
                  Text(l.lifeConsent),
                  Text(
                    widget.expectedRealm.replaceAll('\n', ' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(labelText: l.lifeCategory),
                    items: ['diet', 'bill', 'cart']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(lifeCategory(l, value)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _category = value!),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (date != null && mounted) {
                              setState(() => _date = date);
                            }
                          },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('${l.lifeDate}: ${LifeRecord.day(_date)}'),
                  ),
                  TextFormField(
                    controller: _title,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: l.lifeRecordTitle),
                  ),
                  TextFormField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(labelText: l.lifeNote),
                  ),
                  Text(l.lifeItems),
                  ..._items.map(
                    (row) => Padding(
                      key: ObjectKey(row),
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: row.fields['name'],
                            decoration: InputDecoration(
                              labelText: l.lifeItemName,
                            ),
                            maxLength: 120,
                            validator: (value) =>
                                value!.trim().isEmpty ? l.lifeRequired : null,
                          ),
                          ...['quantity', 'unit', 'amount', 'currency'].map(
                            (key) => TextFormField(
                              controller: row.fields[key],
                              maxLength: key == 'currency' ? 3 : 32,
                              keyboardType: key == 'amount' || key == 'quantity'
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    )
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: switch (key) {
                                  'quantity' => l.lifeQuantity,
                                  'unit' => l.lifeUnit,
                                  'amount' => l.lifeAmount,
                                  _ => l.lifeCurrency,
                                },
                              ),
                              validator: (value) {
                                final text = value!.trim();
                                if (key == 'currency' &&
                                    row.fields['amount']!.text
                                        .trim()
                                        .isNotEmpty &&
                                    !RegExp(r'^[A-Za-z]{3}$').hasMatch(text)) {
                                  return l.lifeCurrencyRequired;
                                }
                                if ((key == 'amount' || key == 'quantity') &&
                                    text.isNotEmpty &&
                                    (!RegExp(
                                          r'^-?\d{1,12}(\.\d{1,6})?$',
                                        ).hasMatch(text) ||
                                        (key == 'quantity' &&
                                            double.parse(text) <= 0))) {
                                  return l.lifeNumberInvalid;
                                }
                                return null;
                              },
                            ),
                          ),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() => _items.remove(row));
                                    row.dispose();
                                  },
                            child: Text(l.lifeRemoveItem),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving || _items.length >= 100
                        ? null
                        : () => setState(() => _items.add(_LifeItemFields({}))),
                    icon: const Icon(Icons.add),
                    label: Text(l.lifeAddItem),
                  ),
                  if (_error != null) Text(lifeStatus(l, _error)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l.lifeCancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l.lifeSaving : l.lifeSave),
          ),
        ],
      ),
    );
  }
}

class _LifeItemFields {
  _LifeItemFields(Map<String, dynamic> data)
    : original = Map<String, dynamic>.from(data),
      fields = {
        for (final key in ['name', 'quantity', 'unit', 'amount', 'currency'])
          key: TextEditingController(text: data[key]?.toString() ?? ''),
      };
  final Map<String, TextEditingController> fields;
  final Map<String, dynamic> original;
  Map<String, dynamic> get value => {
    ...original,
    ...fields.map(
      (key, controller) => MapEntry(
        key,
        key == 'currency'
            ? controller.text.trim().toUpperCase()
            : controller.text.trim(),
      ),
    ),
  };
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}
