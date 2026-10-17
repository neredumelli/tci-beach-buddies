import '../geo/geo.dart';

/// One position sample from a location source.
class LocationFix {
  final GeoPoint position;

  /// Horizontal accuracy radius in metres (68% confidence), as reported by OS.
  final double accuracyM;

  /// Time the fix was produced by the receiver (not the time we read it).
  final DateTime timestamp;

  /// Speed in m/s if known.
  final double? speedMps;

  /// Synthetic fix from Demo mode. Must never be presented as live GPS.
  final bool isSimulated;

  const LocationFix({
    required this.position,
    required this.accuracyM,
    required this.timestamp,
    this.speedMps,
    this.isSimulated = false,
  });

  Duration ageAt(DateTime now) => now.difference(timestamp);

  @override
  String toString() =>
      'LocationFix($position ±${accuracyM.toStringAsFixed(0)}m @${timestamp.toIso8601String()}${isSimulated ? ' SIM' : ''})';
}
