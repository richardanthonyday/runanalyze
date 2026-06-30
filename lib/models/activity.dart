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
    int toInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    int? toNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    double? toNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final sportJson = json['sport'];
    final typeJson = json['type'];

    return Activity(
      id: toInt(json['id']),
      dateTime: DateTime.parse(json['date_time'] as String).toLocal(),
      sport: sportJson is Map ? (sportJson['name']?.toString() ?? 'Unknown') : 'Unknown',
      type: typeJson is Map ? typeJson['name']?.toString() : null,
      distance: toNullableDouble(json['distance']) ?? 0.0,
      duration: toInt(json['duration']),
      hrMax: toNullableInt(json['hr_max']),
      hrAvg: typeJson is Map ? toNullableInt(typeJson['avg_hr']) : null,
      power: toNullableInt(json['power']),
      vo2Max: toNullableDouble(json['vo2max_by_time']),
      temperature: toNullableDouble(json['temperature']),
      weather: json['weather_condition'] as String?,
      note: json['note'] as String?,
    );
  }

  /// Get average pace in min/km.
  double get paceMinPerKm {
    if (distance <= 0) return 0;
    return (duration / 60) / distance;
  }

  /// For 'Sets' or weight workouts, duration in seconds represents set count.
  /// Return set count if this is a Sets workout with no distance recorded.
  /// Checks for "sets" in either type or sport name (case-insensitive) and distance <= 0.
  int? get setsCount {
    final typeStr = type?.toLowerCase() ?? '';
    final sportStr = sport.toLowerCase();
    
    // Check if this is a Sets workout (by type or sport name)
    final isSetWorkout = typeStr.contains('sets') || sportStr.contains('sets');
    
    if (isSetWorkout && distance <= 0) {
      return duration; // duration is stored in seconds = set count
    }
    return null;
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
  String formatPace() {
    if (paceMinPerKm <= 0) return '--:-- min/km';
    final totalSeconds = (paceMinPerKm * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')} min/km';
  }
}
