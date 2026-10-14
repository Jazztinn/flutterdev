import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'xmb_audio.dart';
import 'xmb_menu.dart';
import 'xmb_visuals.dart';

export 'xmb_audio.dart' show XmbSound, XmbSoundPlayer;

import 'pages/activity_1.dart';
import 'pages/activity_2.dart';
import 'pages/activity_3.dart';
import 'pages/activity_4.dart';
import 'pages/activity_placeholder.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.soundPlayer});

  final XmbSoundPlayer? soundPlayer;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // keep menu setup in one place.
  static const _activityCategory = 2;
  static const _responseTime = 0.045;
  static const _activityPages = [
    ActivityOnePage(title: 'JJTunes'),
    ActivityTwoPage(title: 'SkyZine'),
    ActivityThreePage(title: 'Activity 3'),
    ActivityFourPage(title: 'Activity 4'),
  ];
  static const List<Widget?> _categoryPages = [
    ActivityPlaceholderPage(title: 'Info', showConstructionImage: true),
    ActivityPlaceholderPage(title: 'Media', showConstructionImage: true),
    null,
    ActivityPlaceholderPage(title: 'Settings', showConstructionImage: true),
  ];

  late final Ticker _ticker;
  Timer? _clockTimer;
  Timer? _repeatTimer;
  Timer? _launchSoundTimer;
  Duration _lastTick = Duration.zero;
  DateTime _now = DateTime.now();
  LogicalKeyboardKey? _heldKey;
  int _repeatInterval = 180;
  int _selectedCategory = _activityCategory;
  int _selectedActivity = 0;
  double _animatedCategory = _activityCategory.toDouble();
  double _animatedActivity = 0;
  final _waveTime = ValueNotifier<double>(0);
  XmbAudio? _audio;
  bool _openingActivity = false;
  bool _openingPlaceholder = false;

  // send sound to the test player or real player.
  void _sound(XmbSound sound) {
    final player = widget.soundPlayer;
    if (player != null) {
      player(sound);
    } else {
      _audio?.play(sound);
    }
  }

  @override
  // start menu motion, clock, and sound.
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _scheduleClock();
    if (widget.soundPlayer == null) {
      _audio = XmbAudio()..initialize();
    }
  }

  void _tick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    // move menu toward its new position.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1000000)
        .clamp(0.0, 0.05)
        .toDouble();
    _lastTick = elapsed;
    final response = 1 - math.exp(-dt / _responseTime);
    _waveTime.value += dt;
    final categoryDelta = _selectedCategory - _animatedCategory;
    final activityDelta = _selectedActivity - _animatedActivity;
    if (categoryDelta == 0 && activityDelta == 0) return;
    setState(() {
      _animatedCategory = categoryDelta.abs() < 0.001
          ? _selectedCategory.toDouble()
          : _animatedCategory + categoryDelta * response;
      _animatedActivity = activityDelta.abs() < 0.001
          ? _selectedActivity.toDouble()
          : _animatedActivity + activityDelta * response;
    });
  }

  void _scheduleClock() {
    // update the clock on each new minute.
    final milliseconds = (60 - _now.second) * 1000 - _now.millisecond;
    _clockTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  void _selectCategory(int index) {
    // choose a category inside the menu limits.
    final next = index.clamp(0, XmbMenu.categories.length - 1).toInt();
    if (next == _selectedCategory) return;
    setState(() => _selectedCategory = next);
    _sound(XmbSound.navigation);
  }

  void _selectActivity(int index) {
    // choose an activity inside the menu limits.
    final next = index.clamp(0, XmbMenu.activityNames.length - 1).toInt();
    if (next == _selectedActivity) return;
    setState(() => _selectedActivity = next);
    _sound(XmbSound.navigation);
  }

  void _moveCategory(int direction) {
    // move left or right.
    _selectCategory(_selectedCategory + direction);
  }

  void _moveActivity(int direction) {
    // move up or down when activities are open.
    if (_selectedCategory == _activityCategory) {
      _selectActivity(_selectedActivity + direction);
    }
  }

  Future<void> _openActivity(int index) async {
    // open one activity page.
    if (_openingActivity) return;
    _openingActivity = true;
    _stopRepeat();
    _selectActivity(index);
    _sound(XmbSound.confirm);
    _launchSoundTimer = Timer(const Duration(milliseconds: 340), () {
      if (mounted && _openingActivity) _sound(XmbSound.startGame);
    });
    _ticker.stop();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => _activityPages[index]));
    if (mounted) {
      _launchSoundTimer?.cancel();
      _openingActivity = false;
      _lastTick = Duration.zero;
      _ticker.start();
      _sound(XmbSound.back);
    }
  }

  Future<void> _openPlaceholder(Widget page) async {
    // open a category placeholder page.
    if (_openingPlaceholder) return;
    _openingPlaceholder = true;
    _stopRepeat();
    _sound(XmbSound.confirm);
    _ticker.stop();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) {
      _openingPlaceholder = false;
      _lastTick = Duration.zero;
      _ticker.start();
      _sound(XmbSound.back);
    }
  }

  void _openSelectedItem() {
    // open the focused menu page.
    if (_selectedCategory == _activityCategory) {
      unawaited(_openActivity(_selectedActivity));
      return;
    }
    final page = _categoryPages[_selectedCategory];
    if (page != null) unawaited(_openPlaceholder(page));
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    // handle arrows, enter, and held keys.
    final key = event.logicalKey;
    final directional =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;

    if (event is KeyUpEvent && key == _heldKey) {
      _stopRepeat();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      return directional ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _openSelectedItem();
      return KeyEventResult.handled;
    }
    if (!directional) return KeyEventResult.ignored;
    if (_heldKey == key) return KeyEventResult.handled;

    _stopRepeat();
    _heldKey = key;
    _activateKey(key);
    _repeatInterval = 180;
    _repeatTimer = Timer(const Duration(milliseconds: 380), () {
      if (_heldKey != key) return;
      _activateKey(key);
      _scheduleRepeat(key);
    });
    return KeyEventResult.handled;
  }

  void _activateKey(LogicalKeyboardKey key) {
    // apply one key move.
    if (key == LogicalKeyboardKey.arrowLeft) _moveCategory(-1);
    if (key == LogicalKeyboardKey.arrowRight) _moveCategory(1);
    if (key == LogicalKeyboardKey.arrowUp) _moveActivity(-1);
    if (key == LogicalKeyboardKey.arrowDown) _moveActivity(1);
  }

  void _scheduleRepeat(LogicalKeyboardKey key) {
    // repeat held keys faster over time.
    _repeatTimer = Timer(Duration(milliseconds: _repeatInterval), () {
      if (_heldKey != key) return;
      _activateKey(key);
      _repeatInterval = math.max(55, (_repeatInterval * 0.72).round());
      _scheduleRepeat(key);
    });
  }

  void _stopRepeat() {
    // stop key repeat when key is released.
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _heldKey = null;
  }

  String _clockText() {
    // make the clock text.
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour < 12 ? 'AM' : 'PM';
    return '${_now.month}/${_now.day}  $hour:$minute $period';
  }

  @override
  // place wallpaper behind the menu.
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          XmbBackground(time: _waveTime),
          SafeArea(
            child: Focus(
              autofocus: true,
              onKeyEvent: _handleKey,
              onFocusChange: (focused) {
                if (!focused) _stopRepeat();
              },
              child: XmbMenu(
                selectedCategory: _selectedCategory,
                selectedActivity: _selectedActivity,
                animatedCategory: _animatedCategory,
                animatedActivity: _animatedActivity,
                clockText: _clockText(),
                onCategoryTap: _selectCategory,
                onOpenActivity: (index) => unawaited(_openActivity(index)),
                onMoveCategory: _moveCategory,
                onMoveActivity: _moveActivity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  // stop timers and release players.
  void dispose() {
    _stopRepeat();
    _clockTimer?.cancel();
    _launchSoundTimer?.cancel();
    _ticker.dispose();
    _waveTime.dispose();
    _audio?.dispose();
    super.dispose();
  }
}
