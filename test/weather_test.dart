import 'dart:async';
import 'dart:convert';

import 'package:activity_hub/pages/activity_2.dart';
import 'package:activity_hub/pages/weather_data.dart';
import 'package:activity_hub/pages/weather_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

int _unix(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _current({
  String city = 'Imus City',
  int code = 500,
  String icon = '10n',
}) => {
  'name': city,
  'coord': {'lat': 14.4297, 'lon': 120.9367},
  'dt': _unix(DateTime.utc(2026, 10, 14, 14)),
  'timezone': 28800,
  'main': {'temp': 28.4, 'feels_like': 30.2, 'humidity': 82},
  'wind': {'speed': 2.5, 'deg': 225},
  'rain': {'1h': 1.2},
  'sys': {
    'country': 'PH',
    'sunrise': _unix(DateTime.utc(2026, 10, 13, 21, 48)),
    'sunset': _unix(DateTime.utc(2026, 10, 14, 9, 41)),
  },
  'weather': [
    {'id': code, 'icon': icon, 'description': 'light rain'},
  ],
};

Map<String, dynamic> _forecast() => {
  'city': {'timezone': 28800},
  'list': List.generate(
    40,
    (i) => {
      'dt': _unix(DateTime.utc(2026, 10, 14, 15).add(Duration(hours: i * 3))),
      'main': {'temp': 24 + i % 8},
      'pop': i % 2 == 0 ? 0.2 : 0.8,
      if (i % 3 == 0) 'rain': {'3h': 0.9},
      'weather': [
        {'id': 500, 'icon': '10d', 'description': 'light rain'},
      ],
    },
  ),
};

http.Response _json(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
    );

Widget _app(http.Client client, {double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: ActivityTwoPage(title: 'SkyZine', client: client, apiKey: 'test-key'),
);

Future<void> _load(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

void main() {
  test(
    'daily summaries use city dates, sampled temperatures and interval rain',
    () {
      final current = WeatherData.fromJson(_current());
      final forecast = WeatherForecast.fromJson(_forecast(), current);
      expect(forecast.days, hasLength(5));
      final tomorrow = forecast.days.first;
      expect(tomorrow.date, DateTime.utc(2026, 10, 15));
      expect(tomorrow.periods, hasLength(8));
      expect(tomorrow.low, 24);
      expect(tomorrow.high, 31);
      expect(tomorrow.probability, 0.8);
      expect(tomorrow.rainfall, closeTo(1.8, 0.001));
      expect(tomorrow.isPartial, isFalse);
      expect(forecast.days.last.isPartial, isTrue);
      expect(current.localTime.hour, 22);
      expect(weatherLocalTime(current.sunrise!, current.timezone).hour, 5);
    },
  );

  test(
    'condition codes choose sky scenes and provider icon sets day or night',
    () {
      for (final (code, scene) in [
        (800, WeatherScene.clear),
        (803, WeatherScene.cloudy),
        (501, WeatherScene.rain),
        (201, WeatherScene.storm),
        (601, WeatherScene.snow),
        (741, WeatherScene.mist),
      ]) {
        final current = WeatherData.fromJson(_current(code: code));
        expect(current.scene, scene);
        expect(current.isNight, isTrue);
      }
      expect(WeatherData.fromJson(_current(icon: '01d')).isNight, isFalse);
      final dry = _current()..remove('rain');
      expect(WeatherData.fromJson(dry).rainfall, 0);
    },
  );

  testWidgets(
    'loads current metrics and five cards using matching city coordinates',
    (tester) async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        return _json(
          request.url.path.endsWith('/forecast') ? _forecast() : _current(),
        );
      });
      await _load(tester, _app(client));
      expect(find.byKey(const ValueKey('weather-temperature')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('weather-temperature')))
            .data,
        '28°',
      );
      expect(find.text('Light rain'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('weather-forecast-day-$i')), findsOneWidget);
      }
      expect(find.text('Tomorrow'), findsOneWidget);
      for (final key in [
        'rain-chance',
        'rainfall',
        'humidity',
        'wind',
        'sunrise-sunset',
      ]) {
        expect(find.byKey(ValueKey('weather-$key')), findsOneWidget);
      }
      expect(find.text('5:48 AM'), findsOneWidget);
      expect(find.text('5:41 PM'), findsOneWidget);
      final wind = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const ValueKey('weather-wind')),
              matching: find.byType(Text),
            )
            .at(1),
      );
      expect(wind.textSpan!.toPlainText(), '9.0 km/h');
      expect(requests.first.queryParameters['q'], 'Imus City');
      expect(requests.last.queryParameters['lat'], '14.4297');
      expect(requests.last.queryParameters['lon'], '120.9367');
      expect(requests.last.queryParameters['units'], 'metric');
      expect(
        find.byKey(const ValueKey('weather-scene-rain-night')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('keeps current conditions when forecast request fails', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => request.url.path.endsWith('/forecast')
          ? _json({'message': 'Unavailable'}, 503)
          : _json(_current()),
    );
    await _load(tester, _app(client));
    expect(find.text('28°'), findsOneWidget);
    expect(
      find.text('Forecast unavailable. Refresh to try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('weather-humidity')), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-forecast-day-0')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('later search wins when old city response arrives last', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final latest = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/forecast')) return _json(_forecast());
      return switch (request.url.queryParameters['q']) {
        'Old city' => old.future,
        'New city' => latest.future,
        _ => _json(_current()),
      };
    });
    await _load(tester, _app(client));
    final field = find.byKey(const ValueKey('weather-city-field'));
    await tester.enterText(field, 'Old city');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(field, 'New city');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    latest.complete(_json(_current(city: 'New city', code: 800, icon: '01d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    old.complete(_json(_current(city: 'Old city')));
    await tester.pump();
    expect(
      find
          .text('New city', findRichText: false)
          .evaluate()
          .where((element) => element.widget is Text),
      hasLength(1),
    );
    expect(find.text('Old city'), findsNothing);
    expect(
      find.byKey(const ValueKey('weather-scene-clear-day')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'phone and tablet layouts handle larger text and reduced motion',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final (size, textScale) in [
        (const Size(320, 568), 1.0),
        (const Size(768, 1024), 1.0),
        (const Size(1024, 768), 1.0),
        (const Size(1366, 900), 1.0),
        (const Size(320, 568), 1.6),
      ]) {
        tester.view.physicalSize = size;
        final client = MockClient(
          (request) async => _json(
            request.url.path.endsWith('/forecast') ? _forecast() : _current(),
          ),
        );
        await _load(tester, _app(client, textScale: textScale));
        expect(tester.takeException(), isNull, reason: '$size at $textScale');
        expect(find.byType(WeatherBackdrop), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
