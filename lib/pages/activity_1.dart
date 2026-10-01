import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../xmb_visuals.dart';

String _time(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

// show activity one.
class ActivityOnePage extends StatefulWidget {
  final String title;

  const ActivityOnePage({super.key, required this.title});

  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<ActivityOnePage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  final _backgroundTime = ValueNotifier<double>(0);
  late final Ticker _backgroundTicker;
  Duration _lastFrame = Duration.zero;
  Offset _dockTarget = const Offset(52, 56);
  Offset _dockPointer = const Offset(52, 56);
  Offset _coverTarget = Offset.zero;
  Offset _coverPointer = Offset.zero;
  final songs = [
    'music/less.mp3',
    'music/maggotsforbrains.mp3',
    'music/all-the-time-natalie-jinju.m4a',
    'music/fix-you-coldplay.m4a',
    'music/let-down-radiohead.m4a',
    'music/make-up-sam-kim.flac',
    'music/method-acting-demo-lizzy-mcalpine.flac',
    'music/obsessica-malcolm-todd.m4a',
    'music/what-was-i-made-for-billie-eilish.m4a',
    'music/white-ferrari-frank-ocean.m4a',
  ];
  final songTitles = [
    'Less',
    'Maggots for Brains',
    'all the time',
    'Fix You',
    'Let Down',
    'Make Up (Feat. Crush)',
    'Method Acting (Demo)',
    'Obsessica',
    'What Was I Made For?',
    'White Ferrari',
  ];
  final songArtists = [
    'Olivia Rodrigo',
    'Olivia Rodrigo',
    'natalie jinju',
    'Coldplay',
    'Radiohead',
    'SAM KIM',
    'Lizzy McAlpine',
    'Malcolm Todd',
    'Billie Eilish',
    'Frank Ocean',
  ];
  final songAlbums = [
    'Activity 1 playlist',
    'Activity 1 playlist',
    'Last September',
    'X&Y',
    'OK Computer',
    'Sun And Moon',
    'Older (and Wiser)',
    'Do That Again',
    'Barbie soundtrack',
    'Blonde',
  ];
  final songCovers = [
    'assets/images/activity-1-cover.png',
    'assets/images/activity-1-cover.png',
    'assets/images/albums/all-the-time.jpg',
    'assets/images/albums/fix-you.jpg',
    'assets/images/albums/ok-computer.jpg',
    'assets/images/albums/sun-and-moon.jpg',
    'assets/images/albums/older-and-wiser.jpg',
    'assets/images/albums/do-that-again.jpg',
    'assets/images/albums/barbie.jpg',
    'assets/images/albums/blonde.jpg',
  ];

  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1;
  bool _shuffle = false;
  final Set<int> _favoriteTracks = <int>{};
  int _repeatMode = 0;
  int? _hoveredTrack;
  int? _dockFocusTrack;
  bool _dockFocusQueued = false;
  final ScrollController _dockHorizontalController = ScrollController();
  final ScrollController _dockVerticalController = ScrollController();
  Map<String, dynamic> _waveforms = {};

  @override
  void initState() {
    super.initState();
    _dockHorizontalController.addListener(_onHorizontalDockScroll);
    _dockVerticalController.addListener(_onVerticalDockScroll);
    // same clock as home.
    _backgroundTicker = createTicker((elapsed) {
      final dt = (elapsed - _lastFrame).inMicroseconds / 1000000;
      _lastFrame = elapsed;
      final reduced = MediaQuery.disableAnimationsOf(context);
      if (!reduced) {
        _backgroundTime.value += dt.clamp(0.0, 0.05);
      }
      var moved = false;
      final delta = _dockTarget - _dockPointer;
      final response = reduced ? 1.0 : 1 - math.exp(-dt / 0.055);
      if (delta.distance > 0.1) {
        _dockPointer += delta * response;
        moved = true;
      }
      final coverDelta = _coverTarget - _coverPointer;
      if (coverDelta.distance > 0.001) {
        _coverPointer += coverDelta * response;
        moved = true;
      }
      if (moved && mounted) {
        setState(() {});
      }
    })..start();
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((position) => _position = position);
    _loadWaveforms();
  }

  // actual song levels.
  Future<void> _loadWaveforms() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/music/waveforms.json'),
    );
    if (!mounted) return;
    setState(() {
      _waveforms = Map<String, dynamic>.from(data);
      _duration = Duration(
        milliseconds: _waveforms[songs[_currentIndex]]['durationMs'],
      );
    });
  }

  //play selected music
  Future<void> _playSong(int index) async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _dockFocusTrack = index;
      _position = Duration.zero;
      _duration = Duration(
        milliseconds: _waveforms[songs[index]]?['durationMs'] ?? 0,
      );
    });
    await _player.play(AssetSource(songs[index]));
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });
  }

  //pause/resume music
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() {
        _isPlaying = false;
      });
    } else if (_player.source != null &&
        _player.state != PlayerState.completed) {
      await _player.resume();
      setState(() {
        _isPlaying = true;
      });
    } else {
      await _playSong(_currentIndex);
    }
  }

  //next music
  Future<void> _nextSong() async {
    int nextIndex = (_currentIndex + 1) % songs.length;
    await _playSong(nextIndex);
  }

  //previous music
  Future<void> _previousSong() async {
    int previousIndex = (_currentIndex - 1 + songs.length) % songs.length;
    await _playSong(previousIndex);
  }

  // seek before or during play.
  Future<void> _seek(double value) async {
    final target = _duration * value;
    if (_player.source == null) {
      await _player.setSource(AssetSource(songs[_currentIndex]));
    }
    await _player.seek(target);
  }

  //compost
  @override
  void dispose() {
    _backgroundTicker.dispose();
    _backgroundTime.dispose();
    _dockHorizontalController.dispose();
    _dockVerticalController.dispose();
    _player.dispose();
    super.dispose();
  }

  // compact player controls.
  Widget _button(
    IconData icon,
    String label,
    VoidCallback action, {
    bool active = false,
    double size = 38,
  }) => IconButton(
    tooltip: label,
    color: active ? const Color(0xFF8FD7FF) : Colors.white,
    iconSize: size,
    icon: icon == Icons.shuffle || icon == Icons.repeat
        ? CustomPaint(
            size: Size.square(size),
            painter: _PlayerGlyph(
              icon == Icons.shuffle,
              active ? const Color(0xFF8FD7FF) : Colors.white,
            ),
          )
        : Icon(icon),
    onPressed: action,
  );

  String _clockText() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';
    return '${now.month}/${now.day}  $hour:$minute $period';
  }

  double _homeScale(Size size) {
    final landscape = size.width > size.height;
    return ((landscape
                ? math.min(size.width / 960, size.height / 544)
                : math.min(size.width / 480, size.height / 620)) *
            0.84)
        .clamp(0.48, 2.1)
        .toDouble();
  }

  List<int> _orderedDockTracks() {
    return List<int>.generate(songs.length, (index) => index)..sort((a, b) {
      final aFavorite = _favoriteTracks.contains(a);
      final bFavorite = _favoriteTracks.contains(b);
      if (aFavorite == bFavorite) return a.compareTo(b);
      return aFavorite ? -1 : 1;
    });
  }

  void _syncDockFocus(ScrollController controller, bool bottom) {
    if (!controller.hasClients || !mounted) return;
    final tracks = _orderedDockTracks();
    if (tracks.isEmpty) return;
    final position = controller.position;
    final itemStep = bottom ? 120.0 : 136.0;
    final firstCenter = bottom ? 68.0 : 76.0;
    final center = position.pixels + position.viewportDimension / 2;
    final slot = ((center - firstCenter) / itemStep).round().clamp(
      0,
      tracks.length - 1,
    );
    final next = tracks[slot];
    if (_dockFocusTrack == next) return;
    setState(() => _dockFocusTrack = next);
  }

  void _onHorizontalDockScroll() {
    _syncDockFocus(_dockHorizontalController, true);
  }

  void _onVerticalDockScroll() {
    _syncDockFocus(_dockVerticalController, false);
  }

  void _queueDockFocusSync() {
    if (_dockFocusQueued) return;
    _dockFocusQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dockFocusQueued = false;
      if (!mounted) return;
      final bottom = MediaQuery.sizeOf(context).width < 680;
      _syncDockFocus(
        bottom ? _dockHorizontalController : _dockVerticalController,
        bottom,
      );
    });
  }

  Matrix4 _dockTransform(int trackIndex) {
    final hovered = _hoveredTrack == trackIndex;
    final dx = hovered
        ? ((_dockPointer.dx - 52) / 52).clamp(-1.0, 1.0).toDouble()
        : 0.0;
    final dy = hovered
        ? ((_dockPointer.dy - 56) / 56).clamp(-1.0, 1.0).toDouble()
        : 0.0;
    final selected = (_dockFocusTrack ?? _currentIndex) == trackIndex;
    final baseY = selected ? 0.0 : -0.16;
    return Matrix4.identity()
      ..setEntry(3, 2, 0.003)
      ..rotateX(hovered ? -dy * 0.055 : 0)
      ..rotateY(baseY + (hovered ? dx * 0.07 : 0));
  }

  Matrix4 _coverTransform() {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..translateByDouble(_coverPointer.dx * 4, _coverPointer.dy * 4, 0, 1)
      ..rotateX(-_coverPointer.dy * 0.018)
      ..rotateY(_coverPointer.dx * 0.028);
  }

  void _setCoverTarget(Offset position, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    _coverTarget = Offset(
      ((position.dx - center.dx) / center.dx).clamp(-1.0, 1.0).toDouble(),
      ((position.dy - center.dy) / center.dy).clamp(-1.0, 1.0).toDouble(),
    );
  }

  Widget _parallaxCover(Widget cover) {
    return Transform(
      alignment: Alignment.center,
      transform: _coverTransform(),
      child: cover,
    );
  }

  Widget _dockLabel(int trackIndex, bool bottom) {
    final visible =
        trackIndex == (_dockFocusTrack ?? _currentIndex) ||
        trackIndex == _hoveredTrack;
    final begin = bottom ? const Offset(0, 0.18) : const Offset(0, 0.12);
    return SizedBox(
      height: 32,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: visible
            ? DecoratedBox(
                key: ValueKey('title-$trackIndex'),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    songTitles[trackIndex],
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: xmbTextStyle(10),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('hidden-title')),
      ),
    );
  }

  Widget _dockCard(int trackIndex) {
    final selected = trackIndex == (_dockFocusTrack ?? _currentIndex);
    final hovered = trackIndex == _hoveredTrack;
    final size = selected
        ? 82.0
        : hovered
        ? 76.0
        : 60.0;
    final radius = BorderRadius.circular(14);

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(4, 7),
          ),
        ],
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: _dockTransform(trackIndex),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: 'Play ${songTitles[trackIndex]}',
              selected: selected,
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: radius,
                child: InkWell(
                  onFocusChange: (focus) {
                    _dockTarget = const Offset(52, 56);
                    if (focus || _hoveredTrack == trackIndex) {
                      setState(() => _hoveredTrack = focus ? trackIndex : null);
                    }
                  },
                  onTap: () => _playSong(trackIndex),
                  child: Ink(
                    decoration: BoxDecoration(borderRadius: radius),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            songCovers[trackIndex],
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                          ColoredBox(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              border: Border.all(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.78)
                                    : Colors.white.withValues(alpha: 0.22),
                                width: selected ? 2 : 1,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.04),
                                  Colors.black.withValues(alpha: 0.10),
                                ],
                                stops: const [0, 0.32, 1],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.72,
                              heightFactor: 0.28,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.28),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_favoriteTracks.contains(trackIndex))
              const Positioned(
                top: 5,
                right: 5,
                child: Icon(Icons.favorite, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  // music dock.
  Widget _dock() {
    final bottom = MediaQuery.sizeOf(context).width < 680;
    final dockTracks = _orderedDockTracks();

    return SizedBox(
      width: bottom ? dockTracks.length * 120.0 + 16 : 120,
      height: bottom ? 144 : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: bottom ? 8 : 0, vertical: 8),
        child: Flex(
          direction: bottom ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final trackIndex in dockTracks)
              MouseRegion(
                onEnter: (event) {
                  _dockTarget = event.localPosition;
                  if (_hoveredTrack != trackIndex) {
                    setState(() => _hoveredTrack = trackIndex);
                  }
                },
                onHover: (event) {
                  _dockTarget = event.localPosition;
                },
                onExit: (_) {
                  _dockTarget = const Offset(52, 56);
                  if (_hoveredTrack == trackIndex) {
                    setState(() => _hoveredTrack = null);
                  }
                },
                child: SizedBox(
                  height: 136,
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dockCard(trackIndex),
                      const SizedBox(height: 5),
                      _dockLabel(trackIndex, bottom),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiScale = _homeScale(MediaQuery.sizeOf(context));
    _queueDockFocusSync();
    // cover and texture.
    final cover = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: Image.asset(
                  songCovers[_currentIndex],
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    songTitles[_currentIndex],
                    style: xmbTextStyle(
                      MediaQuery.sizeOf(context).width < 600 ? 20 : 30,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    songArtists[_currentIndex],
                    style: xmbTextStyle(
                      MediaQuery.sizeOf(context).width < 600 ? 14 : 18,
                    ).copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    songAlbums[_currentIndex],
                    style: xmbTextStyle(
                      MediaQuery.sizeOf(context).width < 600 ? 10 : 13,
                    ).copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
            _button(
              _favoriteTracks.contains(_currentIndex)
                  ? Icons.favorite
                  : Icons.favorite_border,
              'Favorite',
              () => setState(() {
                if (!_favoriteTracks.add(_currentIndex)) {
                  _favoriteTracks.remove(_currentIndex);
                }
              }),
              active: _favoriteTracks.contains(_currentIndex),
            ),
          ],
        ),
        const SizedBox(height: 38),
        // seek and time.
        StreamBuilder<Duration>(
          key: ValueKey('progress-$_currentIndex'),
          initialData: _position,
          stream: _player.onPositionChanged,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final value = _duration.inMilliseconds == 0
                ? 0.0
                : (position.inMilliseconds / _duration.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  );
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: SliderComponentShape.noThumb,
                    trackShape: const RectangularSliderTrackShape(),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: value,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: _duration == Duration.zero ? null : _seek,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _time(position),
                      style: xmbTextStyle(11).copyWith(color: Colors.white70),
                    ),
                    Text(
                      '-${_time(_duration - position)}',
                      style: xmbTextStyle(11).copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        // transport row.
        LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: constraints.maxWidth.clamp(304.0, double.infinity),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _button(
                    Icons.shuffle,
                    'Shuffle',
                    () => setState(() => _shuffle = !_shuffle),
                    active: _shuffle,
                  ),
                  _button(
                    Icons.fast_rewind,
                    'Previous track',
                    _previousSong,
                    size: 44,
                  ),
                  IconButton.filled(
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF12335B),
                      shape: const CircleBorder(),
                      minimumSize: const Size(54, 54),
                    ),
                    iconSize: 34,
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  _button(
                    Icons.fast_forward,
                    'Next track',
                    _nextSong,
                    size: 44,
                  ),
                  _button(
                    _repeatMode == 2 ? Icons.repeat_one : Icons.repeat,
                    'Repeat',
                    () => setState(() => _repeatMode = (_repeatMode + 1) % 3),
                    active: _repeatMode != 0,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 38),
        // follow playback position.
        StreamBuilder<Duration>(
          key: ValueKey('waveform-$_currentIndex'),
          initialData: _position,
          stream: _player.onPositionChanged,
          builder: (context, snapshot) {
            final data = _waveforms[songs[_currentIndex]];
            final levels = data?['levels'] as List? ?? const [];
            final frame =
                (snapshot.data ?? Duration.zero).inMilliseconds /
                (data?['stepMs'] ?? 50);
            return ExcludeSemantics(
              child: SizedBox(
                height: 82,
                child: Row(
                  children: List.generate(65, (i) {
                    final sample = frame - (64 - i);
                    final index = sample.floor();
                    var level = 0.0;
                    if (index >= 0 && index < levels.length) {
                      final a = (levels[index] as num).toDouble();
                      final b = index + 1 < levels.length
                          ? (levels[index + 1] as num).toDouble()
                          : a;
                      level = a + (b - a) * (sample - index);
                    }
                    return Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 2 + level * _volume * 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
    final volumeMenu = MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFF173454)),
      ),
      builder: (context, controller, _) => IconButton(
        tooltip: 'Volume',
        color: Colors.white,
        iconSize: 24 * uiScale,
        constraints: BoxConstraints.tightFor(
          width: 48 * uiScale,
          height: 48 * uiScale,
        ),
        padding: EdgeInsets.zero,
        icon: Icon(
          _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        SizedBox(
          width: 240 * uiScale,
          child: StatefulBuilder(
            builder: (context, updateMenu) => Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Volume ${(_volume * 100).round()}%',
                    style: xmbTextStyle(13),
                  ),
                  Slider(
                    label: '${(_volume * 100).round()}%',
                    value: _volume,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      updateMenu(() {});
                      _player.setVolume(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: const Color(0xFF071B38),
      body: MouseRegion(
        onEnter: (event) =>
            _setCoverTarget(event.localPosition, MediaQuery.sizeOf(context)),
        onHover: (event) =>
            _setCoverTarget(event.localPosition, MediaQuery.sizeOf(context)),
        onExit: (_) => _coverTarget = Offset.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            XmbBackground(time: _backgroundTime),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        color: Colors.white,
                        iconSize: 30 * uiScale,
                        constraints: BoxConstraints.tightFor(
                          width: 48 * uiScale,
                          height: 48 * uiScale,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          volumeMenu,
                          SizedBox(width: 8 * uiScale),
                          ValueListenableBuilder<double>(
                            valueListenable: _backgroundTime,
                            builder: (context, _, child) => Text(
                              _clockText(),
                              style: xmbTextStyle(21 * uiScale),
                            ),
                          ),
                          SizedBox(width: 13 * uiScale),
                          XmbIcon(
                            kind: XmbIconKind.battery,
                            size: 39 * uiScale,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 54),
                child: LayoutBuilder(
                  builder: (context, shell) {
                    final compact = shell.maxWidth < 680;
                    final dock = Align(
                      alignment: compact
                          ? Alignment.bottomCenter
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 12,
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: compact
                              ? SingleChildScrollView(
                                  controller: _dockHorizontalController,
                                  scrollDirection: Axis.horizontal,
                                  child: _dock(),
                                )
                              : SingleChildScrollView(
                                  controller: _dockVerticalController,
                                  child: _dock(),
                                ),
                        ),
                      ),
                    );
                    final player = LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 680;
                        return Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(wide ? 24 : 12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: wide
                                  ? Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: _parallaxCover(cover),
                                        ),
                                        const SizedBox(width: 48),
                                        Expanded(flex: 6, child: controls),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 300,
                                          ),
                                          child: _parallaxCover(cover),
                                        ),
                                        const SizedBox(height: 28),
                                        controls,
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: [player, dock],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// reference control shapes.
class _PlayerGlyph extends CustomPainter {
  const _PlayerGlyph(this.shuffle, this.color);
  final bool shuffle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lines = Path();
    if (shuffle) {
      lines.moveTo(3, 9);
      lines.cubicTo(19, 9, 21, 31, 36, 31);
      lines.moveTo(3, 31);
      lines.cubicTo(19, 31, 21, 9, 36, 9);
    } else {
      lines.moveTo(4, 28);
      lines.lineTo(4, 10);
      lines.quadraticBezierTo(4, 7, 7, 7);
      lines.lineTo(35, 7);
      lines.moveTo(36, 12);
      lines.lineTo(36, 30);
      lines.quadraticBezierTo(36, 33, 33, 33);
      lines.lineTo(5, 33);
    }
    canvas.drawPath(lines, pen);
    final arrows = shuffle
        ? (Path()
            ..moveTo(32, 5)
            ..lineTo(38, 9)
            ..lineTo(32, 13)
            ..close()
            ..moveTo(32, 27)
            ..lineTo(38, 31)
            ..lineTo(32, 35)
            ..close())
        : (Path()
            ..moveTo(32, 3)
            ..lineTo(38, 7)
            ..lineTo(32, 11)
            ..close()
            ..moveTo(8, 29)
            ..lineTo(2, 33)
            ..lineTo(8, 37)
            ..close());
    canvas.drawPath(arrows, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayerGlyph old) =>
      old.color != color || old.shuffle != shuffle;
}

class SongListScreen extends StatelessWidget {
  final List<String> songs;
  final Function(int) onSongSelected;

  const SongListScreen({
    super.key,
    required this.songs,
    required this.onSongSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select a Song')),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(songs[index]),
            onTap: () => onSongSelected(index),
          );
        },
      ),
    );
  }
}
