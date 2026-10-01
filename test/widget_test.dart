import 'package:activity_hub/home_page.dart';
import 'package:activity_hub/main.dart';
import 'package:activity_hub/xmb_menu.dart';
import 'package:activity_hub/xmb_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp(List<XmbSound> sounds) {
  return MaterialApp(home: HomePage(soundPlayer: sounds.add));
}

void main() {
  testWidgets('main app opens XMB with four activities', (tester) async {
    await tester.pumpWidget(MainApp(soundPlayer: (_) {}));

    expect(find.byType(HomePage), findsOneWidget);
    for (var index = 1; index <= 4; index++) {
      expect(find.text('Activity $index'), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('every activity item opens its matching page', (tester) async {
    final sounds = <XmbSound>[];

    for (var index = 0; index < 4; index++) {
      await tester.pumpWidget(_testApp(sounds));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('activity-$index')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Activity ${index + 1}'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('This page is still under development. Please wait...'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('construction-worker')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('info media and settings open placeholder pages', (tester) async {
    const pages = <(int, String)>[(0, 'Info'), (1, 'Media'), (3, 'Settings')];

    for (final (category, title) in pages) {
      final sounds = <XmbSound>[];
      await tester.pumpWidget(_testApp(sounds));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('category-$category')));
      await tester.pump();
      Focus.of(tester.element(find.byType(XmbMenu))).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sounds, contains(XmbSound.confirm), reason: '$category $sounds');
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(title)),
        findsOneWidget,
      );
      expect(
        find.text('This page is still under development. Please wait...'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('construction-worker')), findsOneWidget);

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('retargeting keeps current fractional rail position', (
    tester,
  ) async {
    final sounds = <XmbSound>[];
    await tester.pumpWidget(_testApp(sounds));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.byKey(const ValueKey('category-1')));
    await tester.pump(const Duration(milliseconds: 30));
    final movingRight = tester
        .getCenter(find.byKey(const ValueKey('category-2')))
        .dx;

    await tester.tap(find.byKey(const ValueKey('category-3')));
    await tester.pump();
    final retargeted = tester
        .getCenter(find.byKey(const ValueKey('category-2')))
        .dx;
    expect((retargeted - movingRight).abs(), lessThan(1));

    await tester.pump(const Duration(milliseconds: 50));
    final movingLeft = tester
        .getCenter(find.byKey(const ValueKey('category-2')))
        .dx;
    expect(movingLeft, lessThan(retargeted));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('swipes clamp selection and sound only successful steps', (
    tester,
  ) async {
    final sounds = <XmbSound>[];
    await tester.pumpWidget(_testApp(sounds));
    await tester.pump();

    await tester.drag(find.byType(HomePage), const Offset(0, 70));
    expect(sounds, isEmpty);

    await tester.drag(find.byType(HomePage), const Offset(0, -70));
    expect(sounds, [XmbSound.navigation]);

    await tester.tap(find.byKey(const ValueKey('category-3')));
    sounds.clear();
    await tester.drag(find.byType(HomePage), const Offset(-70, 0));
    expect(sounds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('held arrow repeats after delay and accelerates', (tester) async {
    final sounds = <XmbSound>[];
    await tester.pumpWidget(_testApp(sounds));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    sounds.clear();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    expect(sounds, [XmbSound.navigation]);
    await tester.pump(const Duration(milliseconds: 379));
    expect(sounds, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(sounds, hasLength(2));
    await tester.pump(const Duration(milliseconds: 180));
    expect(sounds, hasLength(3));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('activity tap sends navigation, confirm, and back cues', (
    tester,
  ) async {
    final sounds = <XmbSound>[];
    await tester.pumpWidget(_testApp(sounds));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('activity-1')));
    expect(sounds, [XmbSound.navigation, XmbSound.confirm]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(sounds.last, XmbSound.back);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('idle waves do not rebuild menu icons', (tester) async {
    await tester.pumpWidget(_testApp(<XmbSound>[]));
    await tester.pump(const Duration(milliseconds: 20));
    final icon = tester.widget(find.byType(XmbIcon).first);
    await tester.pump(const Duration(milliseconds: 20));
    expect(identical(icon, tester.widget(find.byType(XmbIcon).first)), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final settled = tester.widget(find.byType(XmbIcon).first);
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      identical(settled, tester.widget(find.byType(XmbIcon).first)),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('launch cue follows confirm and repeated enter opens one page', (
    tester,
  ) async {
    final sounds = <XmbSound>[];
    await tester.pumpWidget(_testApp(sounds));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sounds.where((sound) => sound == XmbSound.confirm), hasLength(1));
    await tester.pump(const Duration(milliseconds: 340));
    expect(sounds, [XmbSound.confirm, XmbSound.startGame]);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomePage), findsOneWidget);
    expect(sounds.last, XmbSound.back);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('submenu retains fixed focus and previous rows above XMB', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(<XmbSound>[]));
    await tester.pump(const Duration(milliseconds: 20));
    final focusY = tester
        .getCenter(find.byKey(const ValueKey('activity-0')))
        .dy;
    expect(find.text('Laboratory Activity 1'), findsOneWidget);
    final divider = tester.getRect(
      find.byKey(const ValueKey('activity-divider')),
    );
    expect(
      divider.right,
      greaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      ),
    );
    expect(divider.height, greaterThan(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Laboratory Activity 1'), findsNothing);
    expect(find.text('Laboratory Activity 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-divider')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('activity-1'))).dy,
      closeTo(focusY, 0.1),
    );
    final previous = find.byKey(const ValueKey('activity-0'));
    final rail = tester.getRect(find.byKey(const ValueKey('category-2')));
    expect(tester.getRect(previous).bottom, lessThan(rail.top));
    final previousOpacity = tester.widget<Opacity>(
      find.descendant(of: previous, matching: find.byType(Opacity)).first,
    );
    expect(previousOpacity.opacity, greaterThan(0.4));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final faded = tester.widget<Opacity>(
      find.descendant(of: previous, matching: find.byType(Opacity)).first,
    );
    expect(faded.opacity, lessThan(previousOpacity.opacity));
    expect(
      tester.getCenter(find.byKey(const ValueKey('activity-2'))).dy,
      closeTo(focusY, 0.1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('adaptive layouts avoid overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in <Size>[
      const Size(320, 568),
      const Size(844, 390),
      const Size(1024, 1366),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_testApp(<XmbSound>[]));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull, reason: 'Failed at $size');
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
