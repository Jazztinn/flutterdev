import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../xmb_visuals.dart';
import 'weather_data.dart';
import 'weather_scene.dart';

class ActivityTwoPage extends StatefulWidget {
  const ActivityTwoPage({
    super.key,
    required this.title,
    this.client,
    this.apiKey,
  });

  final String title;
  final http.Client? client;
  final String? apiKey;

  @override
  State<ActivityTwoPage> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<ActivityTwoPage> {
  static const _defaultApiKey = 'b436b3e14e0860dfd1f77333867dc565';
  static const _missingKeyMessage = 'Weather is not configured yet.';
  static const _secondary = Color(0xFFDDE8F2);
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final TextEditingController _controller = TextEditingController();
  late final String _apiKey;
  late final http.Client _client;
  late final bool _ownsClient;
  int _requestId = 0;

  String city = 'Imus City';
  String temperature = '--';
  String description = 'Loading weather';
  WeatherData? _weather;
  WeatherForecast? _forecast;
  String? _error, _forecastError;
  bool _isLoading = false, _isForecastLoading = false;

  WeatherPalette get _palette => WeatherPalette.forConditions(
    _weather?.scene ?? WeatherScene.clear,
    _weather?.isNight ?? false,
  );

  @override
  void initState() {
    super.initState();
    _apiKey = widget.apiKey ?? _defaultApiKey;
    _client = widget.client ?? http.Client();
    _ownsClient = widget.client == null;
    if (_apiKey.isEmpty) {
      _error = _missingKeyMessage;
      description = 'Weather unavailable';
    } else {
      unawaited(fetchWeather(city));
    }
  }

  Map<String, dynamic> _responseData(http.Response response) {
    if (response.statusCode != 200) {
      throw _WeatherRequestException(switch (response.statusCode) {
        404 => 'City not found. Check the name and try again.',
        401 => 'Weather key rejected.',
        429 => 'Too many requests. Please try again later.',
        _ => 'Weather unavailable. Try again.',
      });
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> fetchWeather(String cityName) async {
    final query = cityName.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a city name.');
      return;
    }
    if (_apiKey.isEmpty) {
      setState(() => _error = _missingKeyMessage);
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
      _forecastError = null;
    });

    try {
      final url = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
        'q': query,
        'appid': _apiKey,
        'units': 'metric',
      });
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 15));
      if (!mounted || requestId != _requestId) return;
      final current = WeatherData.fromJson(_responseData(response));
      setState(() {
        _weather = current;
        city = current.city;
        temperature = current.temperature?.toStringAsFixed(0) ?? '--';
        description = current.description;
        _forecast = null;
        _isLoading = false;
        _isForecastLoading = true;
      });

      // Use coordinates from the city lookup to keep both requests in one place.
      final location = current.latitude != null && current.longitude != null
          ? <String, String>{
              'lat': '${current.latitude}',
              'lon': '${current.longitude}',
            }
          : <String, String>{'q': query};
      final forecastUrl = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/forecast',
        {...location, 'appid': _apiKey, 'units': 'metric'},
      );
      try {
        final response = await _client
            .get(forecastUrl)
            .timeout(const Duration(seconds: 15));
        if (!mounted || requestId != _requestId) return;
        final forecast = WeatherForecast.fromJson(
          _responseData(response),
          current,
        );
        if (forecast.periods.isEmpty) {
          throw const FormatException('Empty forecast');
        }
        setState(() {
          _forecast = forecast;
          _isForecastLoading = false;
        });
      } on Object {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _isForecastLoading = false;
          _forecastError = 'Forecast unavailable. Refresh to try again.';
        });
      }
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoading = false;
        _isForecastLoading = false;
        _error = error is _WeatherRequestException
            ? error.message
            : 'Connection failed. Check internet and try again.';
      });
    }
  }

  void _submitSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(fetchWeather(_controller.text));
  }

  @override
  void dispose() {
    _requestId++;
    _controller.dispose();
    if (_ownsClient) _client.close();
    super.dispose();
  }

  TextStyle _text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
  }) =>
      xmbTextStyle(size)
          .copyWith(fontWeight: weight, color: color, height: 1.2);

  String _degrees(double? value) => value == null ? '--' : '${value.round()}°';

  String _clock(DateTime time) =>
      '${time.hour % 12 == 0 ? 12 : time.hour % 12}:${time.minute.toString().padLeft(2, '0')} ${time.hour < 12 ? 'AM' : 'PM'}';

  String _sunTime(int? unixTime) => unixTime == null
      ? '--'
      : _clock(weatherLocalTime(unixTime, _weather!.timezone));

  String _sentence(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
    Key? key,
  }) => Container(
    key: key,
    padding: padding,
    decoration: BoxDecoration(
      color: _palette.panel.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
    ),
    child: child,
  );

  Widget _heading(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 15, color: _secondary),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          title.toUpperCase(),
          style: _text(12, weight: FontWeight.w600, color: _secondary),
        ),
      ),
    ],
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 18, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          color: Colors.white,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: _text(23, weight: FontWeight.w600)),
              Text('Weather', style: _text(11, color: _secondary)),
            ],
          ),
        ),
        if (_isLoading || _isForecastLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh weather',
          onPressed: _isLoading || _isForecastLoading
              ? null
              : () => unawaited(fetchWeather(city)),
          color: Colors.white,
          disabledColor: Colors.white54,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );

  Widget _searchField() => TextField(
    key: const ValueKey('weather-city-field'),
    controller: _controller,
    onSubmitted: (_) => _submitSearch(),
    textInputAction: TextInputAction.search,
    style: _text(16),
    cursorColor: Colors.white,
    decoration: InputDecoration(
      hintText: 'Search for a city',
      hintStyle: _text(15, color: _secondary),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: Colors.white70,
        size: 20,
      ),
      suffixIcon: IconButton(
        tooltip: 'Search city',
        onPressed: _submitSearch,
        color: Colors.white,
        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
      ),
      filled: true,
      fillColor: _palette.panel.withValues(alpha: 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
    ),
  );

  Widget _sidebar() => SizedBox(
    width: 270,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(),
          const SizedBox(height: 24),
          Text(
            'CURRENT CITY',
            style: _text(11, weight: FontWeight.w600, color: _secondary),
          ),
          const SizedBox(height: 10),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        city,
                        style: _text(22, weight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '$temperature°',
                      style: _text(38, weight: FontWeight.w300),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_weather case final weather?)
                  Text(
                    _clock(weather.localTime),
                    style: _text(13, color: _secondary),
                  ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    WeatherSymbol(
                      code: _weather?.code ?? 801,
                      night: _weather?.isNight ?? false,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_sentence(description), style: _text(13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Weather at a glance.',
            style: _text(16, weight: FontWeight.w500),
          ),
          const SizedBox(height: 7),
          Text(
            'All times are local to the selected city.',
            style: _text(13, color: _secondary),
          ),
        ],
      ),
    ),
  );

  Widget _hero(bool compact) {
    final weather = _weather;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, compact ? 25 : 20, 8, compact ? 32 : 28),
      child: Column(
        children: [
          if (weather != null)
            Text(
              '${_weekdays[weather.localTime.weekday - 1]}, ${_months[weather.localTime.month - 1]} ${weather.localTime.day} · ${_clock(weather.localTime)}',
              style: _text(13, color: _secondary),
            ),
          const SizedBox(height: 12),
          Text(
            city,
            textAlign: TextAlign.center,
            style: _text(compact ? 32 : 40, weight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            '$temperature°',
            key: const ValueKey('weather-temperature'),
            semanticsLabel: '$temperature degrees Celsius',
            style: _text(
              compact ? 88 : 106,
              weight: FontWeight.w300,
            ).copyWith(height: 1.04),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WeatherSymbol(
                code: weather?.code ?? 801,
                night: weather?.isNight ?? false,
                size: 27,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  _sentence(description),
                  style: _text(21, weight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Feels like ${_degrees(weather?.feelsLike)} · Celsius',
            style: _text(14, color: _secondary),
          ),
        ],
      ),
    );
  }

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: _panel(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: _text(14))),
        ],
      ),
    ),
  );

  Widget _forecastCards() => LayoutBuilder(
    builder: (context, constraints) {
      final days = _forecast?.days ?? [];
      final cardWidth = constraints.maxWidth >= 690
          ? (constraints.maxWidth - 48) / 5
          : 145.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(Icons.calendar_today_outlined, 'Next 5 days'),
          const SizedBox(height: 12),
          if (_isForecastLoading)
            _panel(child: Text('Loading forecast…', style: _text(15)))
          else if (days.isEmpty)
            _panel(
              child: Text(
                'Forecast will appear here when available.',
                style: _text(14, color: _secondary),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < days.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    SizedBox(
                      width: cardWidth,
                      child: _panel(
                        key: ValueKey('weather-forecast-day-$i'),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i == 0 &&
                                      days[i].date
                                              .difference(
                                                DateTime.utc(
                                                  _weather!.localTime.year,
                                                  _weather!.localTime.month,
                                                  _weather!.localTime.day,
                                                ),
                                              )
                                              .inDays ==
                                          1
                                  ? 'Tomorrow'
                                  : _weekdays[days[i].date.weekday - 1],
                              style: _text(15, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_months[days[i].date.month - 1]} ${days[i].date.day}',
                              style: _text(12, color: _secondary),
                            ),
                            const SizedBox(height: 17),
                            WeatherSymbol(
                              code: days[i].representative.code,
                              size: 34,
                            ),
                            const SizedBox(height: 16),
                            Text.rich(
                              TextSpan(
                                text: _degrees(days[i].high),
                                style: _text(24, weight: FontWeight.w500),
                                children: [
                                  TextSpan(
                                    text: '  ${_degrees(days[i].low)}',
                                    style: _text(17, color: _secondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.water_drop_rounded,
                                  color: Color(0xFF9EDCFF),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(days[i].probability * 100).round()}%',
                                  style: _text(13, weight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${days[i].rainfall.toStringAsFixed(1)} mm rain',
                              style: _text(12, color: _secondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              days[i].isPartial ? 'Partial day' : '',
                              style: _text(10, color: _secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Daily summaries of 3-hour readings. Rain chance is the highest chance in a day.',
              style: _text(11, color: _secondary),
            ),
          ],
        ],
      );
    },
  );

  Widget _hourlyForecast() {
    final periods = _forecast?.periods.take(8).toList() ?? [];
    if (periods.isEmpty) return const SizedBox.shrink();
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(Icons.schedule_rounded, 'Every 3 hours'),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in periods)
                  SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        Text(
                          '${period.time.hour % 12 == 0 ? 12 : period.time.hour % 12} ${period.time.hour < 12 ? 'AM' : 'PM'}',
                          style: _text(13, color: _secondary),
                        ),
                        const SizedBox(height: 12),
                        WeatherSymbol(
                          code: period.code,
                          night: period.isNight,
                          size: 27,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _degrees(period.temperature),
                          style: _text(19, weight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(period.probability * 100).round()}%',
                          style: _text(11, color: const Color(0xFFB8E7FF)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String id,
    required IconData icon,
    required String title,
    required String value,
    String unit = '',
    required String note,
    Widget? graphic,
  }) => _panel(
    key: ValueKey('weather-$id'),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(icon, title),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: value,
              style: _text(33, weight: FontWeight.w500),
              children: [
                TextSpan(text: unit.isEmpty ? '' : ' $unit', style: _text(16)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (graphic != null) ...[graphic, const SizedBox(height: 12)],
          Text(note, style: _text(12, color: _secondary)),
        ],
      ),
    ),
  );

  Widget _sunTile() {
    final weather = _weather;
    final sunrise = weather?.sunrise;
    final sunset = weather?.sunset;
    final progress = sunrise != null && sunset != null && sunset > sunrise
        ? ((weather!.observedAt - sunrise) / (sunset - sunrise))
              .clamp(0.0, 1.0)
              .toDouble()
        : null;
    return _panel(
      key: const ValueKey('weather-sunrise-sunset'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(Icons.wb_twilight_rounded, 'Sunrise & sunset'),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: CustomPaint(
                painter: _SunPathPainter(progress, weather?.isNight ?? false),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sunrise', style: _text(11, color: _secondary)),
                      const SizedBox(height: 4),
                      Text(
                        _sunTime(sunrise),
                        style: _text(17, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Sunset', style: _text(11, color: _secondary)),
                      const SizedBox(height: 4),
                      Text(
                        _sunTime(sunset),
                        style: _text(17, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _details() => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = textScale > 1.4 || constraints.maxWidth < 340
          ? 1
          : constraints.maxWidth >= 680
          ? 3
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      final weather = _weather;
      final probability = _forecast?.periods.firstOrNull?.probability;
      final tiles = [
        _metric(
          id: 'rain-chance',
          icon: Icons.umbrella_outlined,
          title: 'Rain chance',
          value: probability == null ? '--' : '${(probability * 100).round()}',
          unit: '%',
          note: 'Next 3-hour forecast',
          graphic: LinearProgressIndicator(
            value: probability ?? 0,
            color: const Color(0xFF9DDCFF),
            backgroundColor: Colors.white12,
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ),
        _metric(
          id: 'rainfall',
          icon: Icons.water_drop_outlined,
          title: 'Rainfall',
          value: weather?.rainfall.toStringAsFixed(1) ?? '--',
          unit: 'mm',
          note: 'Rain recorded in the past hour',
        ),
        _metric(
          id: 'humidity',
          icon: Icons.waves_rounded,
          title: 'Humidity',
          value: weather?.humidity?.toStringAsFixed(0) ?? '--',
          unit: '%',
          note: 'Relative humidity',
          graphic: LinearProgressIndicator(
            value: ((weather?.humidity ?? 0) / 100).clamp(0, 1),
            color: Colors.white70,
            backgroundColor: Colors.white12,
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ),
        _metric(
          id: 'wind',
          icon: Icons.air_rounded,
          title: 'Wind',
          value: weather?.windSpeed == null
              ? '--'
              : (weather!.windSpeed! * 3.6).toStringAsFixed(1),
          unit: 'km/h',
          note: weather?.windDirection == null
              ? 'Direction unavailable'
              : 'From ${weather!.windCompass} · ${weather.windDirection!.round()}°',
        ),
        _metric(
          id: 'feels-like',
          icon: Icons.thermostat_outlined,
          title: 'Feels like',
          value: _degrees(weather?.feelsLike),
          note: 'Based on current conditions',
        ),
        _sunTile(),
      ];
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: tiles
            .map((tile) => SizedBox(width: width, child: tile))
            .toList(),
      );
    },
  );

  Widget _content(bool wide, double width) => SingleChildScrollView(
    key: const ValueKey('weather-scroll'),
    padding: EdgeInsets.fromLTRB(
      wide ? 28 : 18,
      wide ? 0 : 8,
      wide ? 28 : 18,
      28,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wide) _searchField(),
            _hero(width < 600),
            if (_error case final error?) _notice(error),
            if (_forecastError case final error?) _notice(error),
            _forecastCards(),
            const SizedBox(height: 18),
            if (_forecast != null) ...[
              _hourlyForecast(),
              const SizedBox(height: 18),
            ],
            _details(),
            const SizedBox(height: 22),
            Center(
              child: Text(
                'Weather data by OpenWeather',
                style: _text(11, color: _secondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      fontFamily: 'NewRodin',
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF91D3FF),
        brightness: Brightness.dark,
      ),
    ),
    child: Scaffold(
      backgroundColor: _palette.top,
      body: Stack(
        fit: StackFit.expand,
        children: [
          WeatherBackdrop(
            key: ValueKey(
              'weather-scene-${_weather?.scene.name ?? 'clear'}-${_weather?.isNight == true ? 'night' : 'day'}',
            ),
            scene: _weather?.scene ?? WeatherScene.clear,
            night: _weather?.isNight ?? false,
            cloudCover: _weather?.cloudCover ?? 20,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 1100 &&
                    MediaQuery.textScalerOf(context).scale(14) < 20;
                return Column(
                  children: [
                    _header(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wide) _sidebar(),
                          Expanded(
                            child: _content(
                              wide,
                              wide
                                  ? constraints.maxWidth - 270
                                  : constraints.maxWidth,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _SunPathPainter extends CustomPainter {
  const _SunPathPainter(this.progress, this.night);
  final double? progress;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Offset(8, size.height - 5);
    final right = Offset(size.width - 8, size.height - 5);
    final path = Path()..moveTo(left.dx, left.dy);
    path.quadraticBezierTo(
      size.width / 2,
      -size.height * 0.45,
      right.dx,
      right.dy,
    );
    canvas.drawLine(
      left,
      right,
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (progress == null || night) return;
    final x = left.dx + (right.dx - left.dx) * progress!;
    final t = progress!;
    final y =
        math.pow(1 - t, 2) * left.dy +
        2 * (1 - t) * t * (-size.height * 0.45) +
        t * t * right.dy;
    canvas.drawCircle(
      Offset(x, y),
      5,
      Paint()
        ..color = night ? const Color(0xFFDDE8FF) : const Color(0xFFFFD585),
    );
  }

  @override
  bool shouldRepaint(_SunPathPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.night != night;
}

class _WeatherRequestException implements Exception {
  const _WeatherRequestException(this.message);
  final String message;
}
