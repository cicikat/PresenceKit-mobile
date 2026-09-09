import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

class ChatImage extends StatelessWidget {
  const ChatImage({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.imageAttachment,
    button: true,
    child: GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 8,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(
                        context.l10n.imageDecodeFailed,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: context.l10n.closeTooltip,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 126, maxHeight: 170),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, synchronous) =>
                frame != null || synchronous
                ? child
                : const SizedBox(
                    width: 100,
                    height: 70,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.imageDecodeFailed),
            ),
          ),
        ),
      ),
    ),
  );
}
