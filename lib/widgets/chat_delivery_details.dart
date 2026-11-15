import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/chat_controller.dart';
import '../l10n/l10n.dart';
import '../services/mobile_outbox_store.dart';

Future<void> showChatDeliveryDetails(
  BuildContext context,
  ChatController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .75,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final l = context.l10n;
          final rows = controller.pendingOutgoing;
          String label(OutboxEntry row) => switch (row.state) {
            OutboxState.expired => l.chatQueueExpired,
            OutboxState.cancelled => l.chatSendCancelled,
            OutboxState.queued => l.chatOutboxQueued,
            OutboxState.sending => l.chatOutboxSending,
            OutboxState.outcomeUnknown => l.chatOutboxUnknown,
            OutboxState.retryableFailed => l.chatSendFailed,
            OutboxState.skipped => l.chatOutboxSkipped,
            OutboxState.blocked => switch (row.statusCode) {
              401 => l.chatAuthRequired,
              403 => l.chatPermissionRequired,
              413 => l.chatAttachmentTooLarge,
              _ => l.chatPayloadNeedsChange,
            },
          };
          Future<bool> confirm(String title) async =>
              await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: Text(title),
                  content: Text(l.chatOutboxLocalOnly),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(l.cancelAction),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(title),
                    ),
                  ],
                ),
              ) ??
              false;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l.chatConnectionDetails,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(l.chatRequestEvidenceUnavailable),
              if (controller.lastBackendReply?.emotion
                  case final String emotion)
                Text(emotion),
              Text(l.chatRealtimeDetails(controller.realtime.state)),
              if (controller.mobileError != null ||
                  controller.historyError != null)
                Text(l.chatConnectionUnstable),
              if (controller.outboxError != null)
                Text(
                  controller.outboxError == 'corrupt'
                      ? l.chatOutboxCorrupt
                      : l.chatOutboxStorageError,
                ),
              TextButton.icon(
                onPressed: controller.refreshConnection,
                icon: const Icon(Icons.refresh),
                label: Text(l.chatOutboxCheck),
              ),
              Text(
                l.chatPendingCount(
                  rows.where((row) => !row.locallyStopped).length,
                ),
              ),
              if (rows.any(
                (row) =>
                    row.state == OutboxState.outcomeUnknown ||
                    row.state == OutboxState.blocked ||
                    row.state == OutboxState.retryableFailed,
              ))
                Text(l.chatQueuePaused),
              for (final row in rows)
                Builder(
                  builder: (context) {
                    final message = controller.history
                        .followedBy(controller.sent)
                        .where(
                          (m) =>
                              m.role == 'you' && m.requestId == row.requestId,
                        )
                        .firstOrNull;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatShortDate(row.createdAt),
                            ),
                            Text(label(row)),
                            Wrap(
                              children: [
                                if (row.state == OutboxState.outcomeUnknown ||
                                    row.state == OutboxState.skipped)
                                  TextButton(
                                    onPressed: controller.refreshConnection,
                                    child: Text(l.chatOutboxCheck),
                                  ),
                                if (message != null &&
                                    (row.locallyStopped ||
                                        row.state ==
                                            OutboxState.retryableFailed ||
                                        (row.state == OutboxState.blocked &&
                                            (row.statusCode == 401 ||
                                                row.statusCode == 403))))
                                  TextButton(
                                    onPressed: () =>
                                        controller.retryMessage(message),
                                    child: Text(l.chatRetry),
                                  ),
                                if (message != null &&
                                    row.state == OutboxState.queued)
                                  TextButton(
                                    onPressed: () =>
                                        controller.cancelQueuedMessage(message),
                                    child: Text(l.chatCancelSend),
                                  ),
                                if (message != null &&
                                    row.state != OutboxState.sending &&
                                    row.state != OutboxState.skipped &&
                                    !row.locallyStopped)
                                  TextButton(
                                    onPressed: () async {
                                      if (await confirm(l.chatOutboxSkip)) {
                                        await controller.skipOutgoing(message);
                                      }
                                    },
                                    child: Text(l.chatOutboxSkip),
                                  ),
                                if (message != null &&
                                    row.state != OutboxState.sending)
                                  TextButton(
                                    onPressed: () async {
                                      if (await confirm(l.chatOutboxRemove)) {
                                        await controller.removeFromOutbox(
                                          message,
                                        );
                                      }
                                    },
                                    child: Text(l.chatOutboxRemove),
                                  ),
                                IconButton(
                                  tooltip: l.chatCopyDeliveryDetails,
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          'request_id=${row.requestId}; state=${row.state.name}; queued_at=${row.queuedAt.toUtc().toIso8601String()}; http=${row.statusCode ?? '-'}',
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.copy_outlined,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
  ),
);
