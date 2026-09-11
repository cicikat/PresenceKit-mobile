import 'dart:convert';
import 'package:flutter/services.dart';

/// Dedicated facade: native owns durable outbox and shares transport with JobService.
/// No token is passed through this channel or written to the outbox.
class LifeRecordsService {
  static const channel = MethodChannel('presence_mobile/life_records');

  Future<dynamic> invoke(
    String method,
    String origin,
    String owner, [
    Map<String, dynamic> arguments = const {},
  ]) => channel.invokeMethod(method, {
    'origin': origin,
    'owner': owner,
    ...arguments,
  });

  Future<Map<String, dynamic>> object(
    String method,
    String origin,
    String owner, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final value = await invoke(method, origin, owner, arguments);
    return Map<String, dynamic>.from(jsonDecode(value as String) as Map);
  }

  Future<Uint8List?> image(String origin, String owner, String id) async =>
      await invoke('image', origin, owner, {'id': id}) as Uint8List?;
}
