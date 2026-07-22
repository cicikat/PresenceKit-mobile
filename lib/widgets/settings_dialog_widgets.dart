import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

class BackendSettingsResult {
  const BackendSettingsResult({
    required this.baseUrl,
    required this.ownerUserId,
  });

  final String baseUrl;
  final String ownerUserId;
}

class RelaySettingsResult {
  const RelaySettingsResult({
    required this.baseUrl,
    required this.topic,
    required this.token,
  });

  final String baseUrl;
  final String topic;
  final String token;
}

class AdminTokenDialog extends StatefulWidget {
  const AdminTokenDialog({
    super.key,
    required this.c,
    required this.required,
    required this.onSave,
  });

  final YxPalette c;
  final bool required;
  final Future<void> Function(String token) onSave;

  @override
  State<AdminTokenDialog> createState() => _AdminTokenDialogState();
}

class _AdminTokenDialogState extends State<AdminTokenDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _controller.text.trim();
    if (token.isEmpty) {
      setState(() => _error = context.l10n.tokenRequiredError);
      return;
    }
    try {
      await widget.onSave(token);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = context.l10n.saveFailedMessage(error.toString()),
        );
      }
      return;
    }
    if (mounted) Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: widget.c.surface,
      scrollable: true,
      title: Text(
        widget.required ? l10n.tokenSetTitle : l10n.tokenReplaceTitle,
        style: TextStyle(color: widget.c.ink1),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tokenHelp, style: TextStyle(color: widget.c.ink2)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            enableInteractiveSelection: true,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(color: widget.c.ink1),
            decoration: InputDecoration(
              labelText: l10n.settingsAccessTokenTitle,
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (!widget.required)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelAction),
          ),
        FilledButton(onPressed: _save, child: Text(l10n.saveAction)),
      ],
    );
  }
}

class BackendSettingsDialog extends StatefulWidget {
  const BackendSettingsDialog({
    super.key,
    required this.c,
    required this.initialBaseUrl,
    required this.initialOwnerUserId,
    required this.normalizeBaseUrl,
    required this.isOwnerUserIdValid,
  });

  final YxPalette c;
  final String initialBaseUrl;
  final String initialOwnerUserId;
  final Future<String?> Function(String raw) normalizeBaseUrl;
  final bool Function(String value) isOwnerUserIdValid;

  @override
  State<BackendSettingsDialog> createState() => _BackendSettingsDialogState();
}

class _BackendSettingsDialogState extends State<BackendSettingsDialog> {
  late final _baseUrlController = TextEditingController(
    text: widget.initialBaseUrl,
  );
  late final _ownerController = TextEditingController(
    text: widget.initialOwnerUserId,
  );
  String? _baseUrlError;
  String? _ownerError;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalized = await widget.normalizeBaseUrl(_baseUrlController.text);
    if (!mounted) return;
    if (normalized == null) {
      setState(() => _baseUrlError = context.l10n.invalidAddressError);
      return;
    }
    final ownerUserId = _ownerController.text.trim();
    if (ownerUserId.isNotEmpty && !widget.isOwnerUserIdValid(ownerUserId)) {
      setState(() => _ownerError = context.l10n.userIdInvalidError);
      return;
    }
    Navigator.pop(
      context,
      BackendSettingsResult(baseUrl: normalized, ownerUserId: ownerUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: widget.c.surface,
      scrollable: true,
      title: Text(l10n.backendNodeTitle, style: serif(widget.c, 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _baseUrlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: mono(widget.c, 13),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.23:8080',
              errorText: _baseUrlError,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.backendNodeHelp,
            style: serif(widget.c, 12, color: widget.c.ink3),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ownerController,
            keyboardType: TextInputType.text,
            style: mono(widget.c, 13),
            decoration: InputDecoration(
              labelText: l10n.userIdLabel,
              hintText: l10n.userIdHint,
              errorText: _ownerError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.saveReconnectAction)),
      ],
    );
  }
}

class RelaySettingsDialog extends StatefulWidget {
  const RelaySettingsDialog({
    super.key,
    required this.c,
    required this.initialBaseUrl,
    required this.initialTopic,
    required this.initialToken,
    required this.normalizeBaseUrl,
    required this.ensureTrustedOrigin,
    required this.isTopicValid,
  });

  final YxPalette c;
  final String initialBaseUrl;
  final String initialTopic;
  final String initialToken;
  final Future<String?> Function(String raw) normalizeBaseUrl;
  final Future<bool> Function(String normalized) ensureTrustedOrigin;
  final bool Function(String value) isTopicValid;

  @override
  State<RelaySettingsDialog> createState() => _RelaySettingsDialogState();
}

class _RelaySettingsDialogState extends State<RelaySettingsDialog> {
  late final _baseUrlController = TextEditingController(
    text: widget.initialBaseUrl,
  );
  late final _topicController = TextEditingController(
    text: widget.initialTopic,
  );
  late final _tokenController = TextEditingController(
    text: widget.initialToken,
  );
  String? _baseUrlError;
  String? _topicError;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _topicController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final topic = _topicController.text.trim();
    if (topic.isNotEmpty && !widget.isTopicValid(topic)) {
      setState(() => _topicError = context.l10n.relayTopicInvalidError);
      return;
    }
    final rawBaseUrl = _baseUrlController.text.trim();
    var baseUrl = '';
    if (rawBaseUrl.isNotEmpty) {
      final normalized = await widget.normalizeBaseUrl(rawBaseUrl);
      if (!mounted) return;
      if (normalized == null) {
        setState(() => _baseUrlError = context.l10n.invalidAddressError);
        return;
      }
      if (!await widget.ensureTrustedOrigin(normalized)) {
        if (mounted) {
          setState(() => _baseUrlError = context.l10n.untrustedAddressError);
        }
        return;
      }
      baseUrl = normalized;
    }
    if (mounted) {
      Navigator.pop(
        context,
        RelaySettingsResult(
          baseUrl: baseUrl,
          topic: topic,
          token: _tokenController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: widget.c.surface,
      scrollable: true,
      title: Text(l10n.relayDialogTitle, style: serif(widget.c, 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _baseUrlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: mono(widget.c, 13),
            decoration: InputDecoration(
              labelText: l10n.relayAddressLabel,
              hintText: 'https://ntfy.sh 或 http://192.168.x.x:8090',
              errorText: _baseUrlError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            keyboardType: TextInputType.text,
            style: mono(widget.c, 13),
            decoration: InputDecoration(
              labelText: 'topic',
              hintText: l10n.relayTopicHint,
              errorText: _topicError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            keyboardType: TextInputType.text,
            style: mono(widget.c, 13),
            decoration: InputDecoration(
              labelText: l10n.relayTokenLabel,
              hintText: l10n.relayTokenHint,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.relayHelp,
            style: serif(widget.c, 12, color: widget.c.ink3),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.saveAction)),
      ],
    );
  }
}
