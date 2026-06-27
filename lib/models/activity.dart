/// Activity represents a single workout/run from Runalyze API.
class Activity {
  final int id;
  final DateTime dateTime;
  final String sport; // 'Running', 'Cycling', etc.
  final String? type; // 'Easy run', 'Long run', etc.
  final double distance; // km
  final int duration; // seconds (active time)
  final int? hrMax;
  final int? hrAvg;
  final int? power;
  final double? vo2Max;
  final double? temperature;
  final String? weather;
  final String? note;

  Activity({
    required this.id,
    required this.dateTime,
    required this.sport,
    this.type,
    required this.distance,
    required this.duration,
    this.hrMax,
    this.hrAvg,
    this.power,
    this.vo2Max,
    this.temperature,
    this.weather,
    this.note,
  });

  /// Parse Activity from Runalyze API JSON response.
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int,
      dateTime: DateTime.parse(json['date_time'] as String),
      sport: json['sport']?['name'] ?? 'Unknown',
      type: json['type']?['name'],
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: json['duration'] as int? ?? 0,
      hrMax: json['hr_max'] as int?,
      hrAvg: json['type']?['avg_hr'] as int?,
      power: json['power'] as int?,
      vo2Max: (json['vo2max_by_time'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      weather: json['weather_condition'] as String?,
      note: json['note'] as String?,
    );
  }

  /// Get average pace in min/km.
  double get paceMinPerKm {
    if (distance <= 0) return 0;
    return (duration / 60) / distance;
  }

  /// Format duration as human-readable string.
  String formatDuration() {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format pace as string.
  String formatPace() => '${paceMinPerKm.toStringAsFixed(2)} min/km';
}
