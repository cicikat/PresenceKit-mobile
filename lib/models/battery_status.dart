/// A battery reading from the platform channel.
///
/// Every field is nullable on purpose: a device that will not say whether it
/// is charging is not the same as a device that says it is not. Reporting a
/// made-up `false` would make the character describe the phone as unplugged
/// with the same confidence as a real reading, so an unknown field is simply
/// omitted from the upload.
class BatteryStatus {
  const BatteryStatus({this.percent, this.charging, this.plugged});

  /// Parses the `readBatteryStatus` channel reply. Unknown or out-of-range
  /// values collapse to null rather than to a guess.
  factory BatteryStatus.fromChannel(Map<Object?, Object?> reply) {
    final percent = reply['percent'];
    final charging = reply['charging'];
    final plugged = reply['plugged']?.toString().trim();
    return BatteryStatus(
      percent: percent is int && percent >= 0 && percent <= 100 ? percent : null,
      charging: charging is bool ? charging : null,
      plugged: plugged != null && pluggedValues.contains(plugged)
          ? plugged
          : null,
    );
  }

  /// Mirrors the backend whitelist on `POST /sensor/push`.
  static const pluggedValues = {'ac', 'usb', 'wireless', 'none'};

  final int? percent;
  final bool? charging;
  final String? plugged;

  bool get isEmpty => percent == null && charging == null && plugged == null;

  @override
  bool operator ==(Object other) =>
      other is BatteryStatus &&
      other.percent == percent &&
      other.charging == charging &&
      other.plugged == plugged;

  @override
  int get hashCode => Object.hash(percent, charging, plugged);

  @override
  String toString() =>
      'BatteryStatus(percent: $percent, charging: $charging, plugged: $plugged)';
}
