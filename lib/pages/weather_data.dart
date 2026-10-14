import 'dart:math' as math;

enum WeatherScene { clear, cloudy, rain, storm, snow, mist }

WeatherScene weatherScene(int code) {
  if (code < 300) return WeatherScene.storm;
  if (code < 600) return WeatherScene.rain;
  if (code < 700) return WeatherScene.snow;
  if (code < 800) return WeatherScene.mist;
  return code == 800 ? WeatherScene.clear : WeatherScene.cloudy;
}

DateTime weatherLocalTime(int unixTime, int timezone) =>
    DateTime.fromMillisecondsSinceEpoch(
      unixTime * 1000,
      isUtc: true,
    ).add(Duration(seconds: timezone));

double? _number(dynamic value) => value is num ? value.toDouble() : null;

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

Map<String, dynamic> _condition(Map<String, dynamic> data) {
  final conditions = data['weather'];
  return conditions is List && conditions.isNotEmpty
      ? _map(conditions.first)
      : const {};
}

class WeatherData {
  WeatherData.fromJson(Map<String, dynamic> data)
    : city = data['name'] as String? ?? 'Unknown city',
      country = _map(data['sys'])['country'] as String? ?? '',
      temperature = _number(_map(data['main'])['temp']),
      feelsLike = _number(_map(data['main'])['feels_like']),
      humidity = _number(_map(data['main'])['humidity']),
      windSpeed = _number(_map(data['wind'])['speed']),
      windDirection = _number(_map(data['wind'])['deg']),
      rainfall = _number(_map(data['rain'])['1h']) ?? 0,
      cloudCover =
          _number(_map(data['clouds'])['all']) ??
          (((_condition(data)['id'] as num?)?.toInt() ?? 801) < 803 ? 20 : 80),
      sunrise = (_map(data['sys'])['sunrise'] as num?)?.toInt(),
      sunset = (_map(data['sys'])['sunset'] as num?)?.toInt(),
      latitude = _number(_map(data['coord'])['lat']),
      longitude = _number(_map(data['coord'])['lon']),
      timezone = (data['timezone'] as num?)?.toInt() ?? 0,
      observedAt =
          (data['dt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      code = (_condition(data)['id'] as num?)?.toInt() ?? 801,
      description = _condition(data)['description'] as String? ?? 'Unavailable',
      icon = _condition(data)['icon'] as String? ?? '02d';

  final String city, country, description, icon;
  final double? temperature, feelsLike, humidity, windSpeed, windDirection;
  final double? latitude, longitude;
  final double rainfall, cloudCover;
  final int? sunrise, sunset;
  final int timezone, observedAt, code;

  bool get isNight => icon.endsWith('n');
  WeatherScene get scene => weatherScene(code);
  DateTime get localTime => weatherLocalTime(observedAt, timezone);
  String get windCompass {
    final degrees = windDirection;
    if (degrees == null) return 'Direction unavailable';
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[(degrees / 45).round() % directions.length];
  }
}

class ForecastPeriod {
  ForecastPeriod.fromJson(Map<String, dynamic> data, int timezone)
    : time = weatherLocalTime((data['dt'] as num).toInt(), timezone),
      temperature = (_map(data['main'])['temp'] as num).toDouble(),
      probability = (_number(data['pop']) ?? 0).clamp(0, 1).toDouble(),
      rainfall = _number(_map(data['rain'])['3h']) ?? 0,
      code = (_condition(data)['id'] as num?)?.toInt() ?? 801,
      description = _condition(data)['description'] as String? ?? 'Unavailable',
      isNight = (_condition(data)['icon'] as String? ?? '02d').endsWith('n');

  final DateTime time;
  final double temperature, probability, rainfall;
  final int code;
  final String description;
  final bool isNight;
}

class DailyForecast {
  DailyForecast(this.date, this.periods) {
    low = periods.map((period) => period.temperature).reduce(math.min);
    high = periods.map((period) => period.temperature).reduce(math.max);
    probability = periods.map((period) => period.probability).reduce(math.max);
    rainfall = periods.fold(0, (total, period) => total + period.rainfall);
    // Use the available period nearest noon for the day's condition icon.
    representative = periods.reduce(
      (a, b) => (a.time.hour - 12).abs() <= (b.time.hour - 12).abs() ? a : b,
    );
  }

  final DateTime date;
  final List<ForecastPeriod> periods;
  late final double low, high, probability, rainfall;
  late final ForecastPeriod representative;
  bool get isPartial => periods.length < 8;
}

class WeatherForecast {
  WeatherForecast.fromJson(Map<String, dynamic> data, WeatherData current) {
    final timezone =
        (_map(data['city'])['timezone'] as num?)?.toInt() ?? current.timezone;
    periods =
        (data['list'] as List)
            .map((item) => ForecastPeriod.fromJson(_map(item), timezone))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final groups = <DateTime, List<ForecastPeriod>>{};
    for (final period in periods) {
      final date = DateTime.utc(
        period.time.year,
        period.time.month,
        period.time.day,
      );
      groups.putIfAbsent(date, () => []).add(period);
    }
    final now = weatherLocalTime(current.observedAt, timezone);
    final today = DateTime.utc(now.year, now.month, now.day);
    days = groups.entries
        .where((entry) => entry.key.isAfter(today))
        .take(5)
        .map((entry) => DailyForecast(entry.key, entry.value))
        .toList();
  }

  late final List<ForecastPeriod> periods;
  late final List<DailyForecast> days;
}
