import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/finance_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

String financeDirection(AppLocalizations l, String? v) => switch (v) {
  'expense' => l.financeExpense,
  'income' => l.financeIncome,
  'refund' => l.financeRefund,
  'transfer' => l.financeTransfer,
  _ => l.financeUnknown,
};
String financeStatus(AppLocalizations l, String? v) => switch (v) {
  'ready' || 'synced' => l.financeSynced,
  'auth' || 'http_401' => l.lifeAuth,
  'forbidden' || 'http_403' => l.lifeForbidden,
  'disabled' => l.financeDisabled,
  'permission_required' => l.financePermissionMissing,
  'paused' => l.financePaused,
  'conflict' => l.lifeConflict,
  'rejected' || 'invalid_record' || 'invalid_response' => l.lifeRejected,
  'account_changed' => l.lifeAccountChanged,
  'setup_required' || 'origin_untrusted' => l.lifeSetup,
  'offline' => l.lifeOffline,
  'rate_limited' => l.lifeRateLimited,
  'unsupported' => l.lifeNotIntegrated,
  'storage_error' => l.lifeStorageError,
  _ => l.financePendingSync,
};
String financeMoney(dynamic value) => value is int
    ? '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}'
    : '—';

String financeSource(AppLocalizations l, dynamic value) => switch (value) {
  'com.tencent.mm' => l.financeWechat,
  'com.eg.android.AlipayGphone' => l.financeAlipay,
  'manual' => l.financeManual,
  _ => l.financeBank,
};
DateTime financeDate(Map<String, dynamic> row) =>
    DateTime.fromMillisecondsSinceEpoch(
      row['occurred_at'] as int,
      isUtc: true,
    ).add(Duration(minutes: row['timezone_offset_minutes'] as int? ?? 0));

String financeTimestamp(Map<String, dynamic> row) {
  final offset = row['timezone_offset_minutes'] as int? ?? 0;
  final absolute = offset.abs();
  final zone =
      '${offset < 0 ? '-' : '+'}${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
  return '${financeDate(row).toIso8601String().substring(0, 16).replaceFirst('T', ' ')} $zone';
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.c, required this.controller});
  final YxPalette c;
  final FinanceController controller;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with WidgetsBindingObserver {
  Timer? _timer;
  bool _confirmed = false;
  String _month = '', _category = '';
  FinanceController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => controller.refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final l = context.l10n;
    final expected = controller.loadedRealm;
    final amount = TextEditingController(
      text: row?['amount_minor'] == null
          ? ''
          : financeMoney(row!['amount_minor']),
    );
    final merchant = TextEditingController(
      text: row?['merchant'] as String? ?? '',
    );
    final category = TextEditingController(
      text: row?['category'] as String? ?? '',
    );
    String direction = row?['direction'] as String? ?? 'expense';
    final form = GlobalKey<FormState>();
    final editorRoute = DialogRoute<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(row == null ? l.financeManual : l.financeEdit),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amount,
                    decoration: InputDecoration(labelText: l.financeAmount),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) =>
                        v != null &&
                            RegExp(
                              r'^(0|[1-9][0-9]{0,8})(\.[0-9]{1,2})?$',
                            ).hasMatch(v) &&
                            v.replaceAll(RegExp(r'[0.]'), '').isNotEmpty
                        ? null
                        : l.financeInvalidAmount,
                  ),
                  DropdownButtonFormField<String>(
                    value: direction,
                    isExpanded: true,
                    items:
                        ['expense', 'income', 'refund', 'transfer', 'unknown']
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(financeDirection(l, v)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => update(() => direction = v!),
                  ),
                  TextField(
                    controller: merchant,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: l.financeMerchant),
                  ),
                  TextField(
                    controller: category,
                    maxLength: 80,
                    decoration: InputDecoration(labelText: l.financeCategory),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.financeCancel),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final pieces = amount.text.split('.');
                final minor =
                    int.parse(pieces[0]) * 100 +
                    int.parse(
                      (pieces.length == 2 ? pieces[1] : '').padRight(2, '0'),
                    );
                Navigator.pop(ctx, {
                  'amount_minor': minor,
                  'currency': 'CNY',
                  'direction': direction,
                  'merchant': merchant.text.trim(),
                  'category': category.text.trim(),
                  'status':
                      row?['status'] == 'confirmed' && direction != 'unknown'
                      ? 'confirmed'
                      : 'candidate',
                });
              },
              child: Text(l.financeSave),
            ),
          ],
        ),
      ),
    );
    final patch = await Navigator.of(context).push(editorRoute);
    await editorRoute.completed;
    amount.dispose();
    merchant.dispose();
    category.dispose();
    if (patch == null || !mounted) return;
    if (row == null) {
      final now = DateTime.now();
      await controller.action('manual', {
        'record': jsonEncode({
          ...patch,
          'occurred_at': now.millisecondsSinceEpoch,
          'observed_at': now.millisecondsSinceEpoch,
          'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
        }),
      }, expectedRealm: expected);
    } else {
      await controller.edit(row, patch, expected);
    }
  }

  Future<void> _history(Map<String, dynamic> row) async {
    final l = context.l10n;
    try {
      final expected = controller.realm;
      final raw = await controller.service.invoke(
        'detail',
        controller.origin(),
        controller.owner(),
        {'id': row['candidate_id']},
      );
      if (!mounted || expected != controller.realm) return;
      final value = jsonDecode(raw as String) as Map;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.financeHistory),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${financeSource(l, row['source_app'])} · ${financeTimestamp(row)}',
                  ),
                  ...(value['history'] as List).map(
                    (e) => ListTile(
                      title: Text(
                        '${financeMoney(e['amount_minor'])} ${e['currency'] ?? ''} · ${financeDirection(l, e['direction'] as String?)}',
                      ),
                      subtitle: Text(
                        '${l.financeRevision} ${e['revision']} · ${e['merchant'] ?? ''}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.financeCancel),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.financeHistoryUnavailable)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = context.l10n;
      final c = widget.c;
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final synced = controller.records.where(
        (r) =>
            r['sync_status'] == 'synced' &&
            r['status'] == 'confirmed' &&
            r['direction'] == 'expense' &&
            financeDate(r).toString().startsWith(month),
      );
      final total = synced.fold<int>(
        0,
        (sum, r) => sum + (r['amount_minor'] as int? ?? 0),
      );
      final records = controller.records
          .where(
            (r) =>
                r['status'] != 'deleted' &&
                (_confirmed
                    ? r['status'] == 'confirmed'
                    : r['status'] != 'confirmed') &&
                (_month.isEmpty ||
                    financeDate(r).toString().startsWith(_month)) &&
                (_category.isEmpty || r['category'] == _category),
          )
          .toList();
      String? day;
      return Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.ink1,
          title: Text(l.financeTitle),
        ),
        body: DefaultTextStyle(
          style: serif(c, 14),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.financeNotice, style: serif(c, 13)),
              Text(l.financeChannels, style: serif(c, 13)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.financeCollect),
                subtitle: Text(
                  controller.permission
                      ? l.financePermissionGranted
                      : l.financePermissionMissing,
                ),
                value: controller.enabled,
                onChanged: controller.busy
                    ? null
                    : (v) => controller.action('setEnabled', {'enabled': v}),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.action('permissionSettings', {}),
                    child: Text(l.financePermission),
                  ),
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.refresh(sync: true),
                    child: Text(l.lifeSync),
                  ),
                  FilledButton(
                    onPressed: controller.busy ? null : () => _edit(),
                    child: Text(l.financeManual),
                  ),
                ],
              ),
              if (controller.busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(financeStatus(l, controller.status)),
              ),
              Text(
                '${l.financeLocalMonth}: ${financeMoney(total)} CNY',
                style: serif(c, 16),
              ),
              Text(l.financeLocalScope, style: serif(c, 12)),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.financeCandidates),
                    selected: !_confirmed,
                    onSelected: (_) => setState(() => _confirmed = false),
                  ),
                  ChoiceChip(
                    label: Text(l.financeLedger),
                    selected: _confirmed,
                    onSelected: (_) => setState(() => _confirmed = true),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(l.financeThisMonth),
                    selected: _month.isNotEmpty,
                    onSelected: (v) => setState(() => _month = v ? month : ''),
                  ),
                  ...controller.records
                      .map((r) => r['category'] as String? ?? '')
                      .where((v) => v.isNotEmpty)
                      .toSet()
                      .map(
                        (v) => FilterChip(
                          label: Text(v),
                          selected: _category == v,
                          onSelected: (on) =>
                              setState(() => _category = on ? v : ''),
                        ),
                      ),
                ],
              ),
              if (records.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.financeEmpty),
                ),
              ...records.expand<Widget>((r) {
                final date = financeDate(r).toString().substring(0, 10);
                final heading = day != date;
                day = date;
                final expected = controller.loadedRealm;
                final reasons = (r['reason_codes'] as List? ?? []);
                final ready =
                    r['amount_minor'] is int &&
                    r['currency'] == 'CNY' &&
                    r['direction'] != 'unknown';
                final state = r['sync_status'] == 'synced'
                    ? (r['status'] == 'confirmed'
                          ? l.financeSynced
                          : l.financeSavedCandidate)
                    : financeStatus(l, r['sync_status'] as String?);
                return [
                  if (heading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(date),
                    ),
                  Card(
                    color: c.surfaceSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${financeMoney(r['amount_minor'])} ${r['currency'] ?? ''} · ${financeDirection(l, r['direction'] as String?)}',
                            style: serif(c, 18),
                          ),
                          Text(
                            '${r['merchant'] ?? l.financeMerchantMissing} · ${financeSource(l, r['source_app'])}',
                          ),
                          Text(state),
                          if (reasons.contains('possible_duplicate'))
                            Text(l.financePossibleDuplicate),
                          if (reasons.contains('amount_incomplete'))
                            Text(l.financeMissingAmount),
                          if (r['status'] == 'ignored' ||
                              r['status'] == 'duplicate')
                            Text(l.financeIgnored),
                          Wrap(
                            spacing: 4,
                            children: [
                              if (r['status'] != 'confirmed')
                                TextButton(
                                  onPressed: controller.busy || !ready
                                      ? null
                                      : () => controller.edit(r, {
                                          'status': 'confirmed',
                                        }, expected),
                                  child: Text(l.financeConfirm),
                                ),
                              TextButton(
                                onPressed: controller.busy
                                    ? null
                                    : () => _edit(r),
                                child: Text(l.financeEdit),
                              ),
                              TextButton(
                                onPressed: controller.busy
                                    ? null
                                    : () => controller.edit(r, {
                                        'status': 'ignored',
                                      }, expected),
                                child: Text(l.financeIgnore),
                              ),
                              TextButton(
                                onPressed: controller.busy
                                    ? null
                                    : () => controller.edit(r, {
                                        'status': 'deleted',
                                      }, expected),
                                child: Text(l.financeDelete),
                              ),
                              TextButton(
                                onPressed: () => _history(r),
                                child: Text(l.financeHistory),
                              ),
                              if (r['sync_status'] == 'conflict')
                                TextButton(
                                  onPressed: controller.busy
                                      ? null
                                      : () => controller.action(
                                          'acceptServer',
                                          {'id': r['candidate_id']},
                                        ),
                                  child: Text(l.financeAcceptServer),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }),
            ],
          ),
        ),
      );
    },
  );
}
