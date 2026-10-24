import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Only a network epoch crosses the bridge; no addresses or VPN metadata.
class NetworkStatusService {
  const NetworkStatusService();

  static const channel = EventChannel('presence_mobile/network');

  Stream<void> get changes => !kIsWeb && Platform.isAndroid
      ? channel.receiveBroadcastStream().map<void>((_) {})
      : const Stream<void>.empty();
}
