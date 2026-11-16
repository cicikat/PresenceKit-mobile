import 'dart:convert';
import 'package:flutter/services.dart';

class FinanceService {
  static const channel = MethodChannel('presence_mobile/finance');
  Future<dynamic> invoke(
    String method,
    String origin,
    String owner, [
    Map<String, dynamic> args = const {},
  ]) =>
      channel.invokeMethod(method, {'origin': origin, 'owner': owner, ...args});
  Future<Map<String, dynamic>> snapshot(String origin, String owner) async =>
      Map<String, dynamic>.from(
        jsonDecode(await invoke('snapshot', origin, owner) as String) as Map,
      );
}
