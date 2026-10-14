import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'xmb_visuals.dart';

class XmbMenu extends StatefulWidget {
  const XmbMenu({
    super.key,
    required this.selectedCategory,
    required this.selectedActivity,
    required this.animatedCategory,
    required this.animatedActivity,
    required this.clockText,
    required this.onCategoryTap,
    required this.onOpenActivity,
    required this.onMoveCategory,
    required this.onMoveActivity,
  });

  // names shown across the top.
  static const categories = ['Info', 'Media', 'Activities', 'Settings'];

  // names shown in the activity list.
  static const activityNames = [
    'JJTunes',
    'SkyZine',
    'Activity 3',
    'Activity 4',
  ];

  final int selectedCategory;
  final int selectedActivity;
  final double animatedCategory;
  final double animatedActivity;
  final String clockText;
  final ValueChanged<int> onCategoryTap;
  final ValueChanged<int> onOpenActivity;
  final ValueChanged<int> onMoveCategory;
  final ValueChanged<int> onMoveActivity;

  @override
  State<XmbMenu> createState() => _XmbMenuState();
}

class _XmbMenuState extends State<XmbMenu> {
  // collect drag movement before changing focus.
  Offset _dragDistance = Offset.zero;

  void _finishDrag(double threshold) {
    // turn one swipe into one menu step.
    final horizontal = _dragDistance.dx.abs() > _dragDistance.dy.abs();
    if (horizontal && _dragDistance.dx.abs() >= threshold) {
      widget.onMoveCategory(_dragDistance.dx < 0 ? 1 : -1);
    } else if (!horizontal && _dragDistance.dy.abs() >= threshold) {
      widget.onMoveActivity(_dragDistance.dy < 0 ? 1 : -1);
    }
    _dragDistance = Offset.zero;
  }

  double _focus(double distance) {
    // make nearby items brighter and larger.
    final value = distance.abs().clamp(0.0, 1.0).toDouble();
    return 1 - value * value * (3 - 2 * value);
  }

  @override
  // size and draw the menu.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final landscape = width > height;
        final scale =
            ((landscape
                        ? math.min(width / 960, height / 544)
                        : math.min(width / 480, height / 620)) *
                    0.84)
                .clamp(0.48, 2.1)
                .toDouble();
        final iconSize = 76 * scale;
        final horizontalGap = 166 * scale;
        final verticalGap = 68 * scale;
        final anchorX = width / 2 - 70 * scale;
        final anchorY = (height - 374 * scale) / 2 + iconSize / 2;
        final activityAnchorY = anchorY + 132 * scale;
        final itemWidth = 144 * scale;
        final fontSize = 22 * scale;
        final categoryVisibility = _focus(widget.animatedCategory - 2);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _dragDistance = Offset.zero,
          onPanUpdate: (details) => _dragDistance += details.delta,
          onPanEnd: (_) => _finishDrag(36 * scale),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // draw category icons.
              ...List.generate(XmbMenu.categories.length, (index) {
                final distance = index - widget.animatedCategory;
                final focus = _focus(distance);
                final x = anchorX + distance * horizontalGap;
                return Positioned(
                  key: ValueKey('category-$index'),
                  left: x - itemWidth / 2,
                  top: anchorY - iconSize / 2,
                  width: itemWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => widget.onCategoryTap(index),
                    child: Semantics(
                      button: true,
                      selected: index == widget.selectedCategory,
                      label: XmbMenu.categories[index],
                      excludeSemantics: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: 0.76 + 0.24 * focus,
                            child: Transform.scale(
                              scale: 0.86 + 0.14 * focus,
                              child: XmbIcon(
                                kind: XmbIconKind.values[index],
                                size: iconSize,
                                selected: focus > 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 5 * scale),
                          Opacity(
                            opacity: focus,
                            child: Text(
                              XmbMenu.categories[index],
                              maxLines: 1,
                              style: xmbTextStyle(fontSize),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // draw activity rows.
              ...List.generate(XmbMenu.activityNames.length, (index) {
                final distance = index - widget.animatedActivity;
                final focus = _focus(distance);
                final aboveFocus = (-distance).clamp(0.0, 1.0);
                final railClearance =
                    Curves.easeInOut.transform(aboveFocus) * 144 * scale;
                final y =
                    activityAnchorY + distance * verticalGap - railClearance;
                final fadeStart = anchorY - iconSize / 2 - verticalGap / 2;
                final topFade = ((y - fadeStart + 100 * scale) / (100 * scale))
                    .clamp(0.0, 1.0);
                final opacity =
                    (categoryVisibility * topFade * (0.66 + 0.34 * focus))
                        .clamp(0.0, 1.0)
                        .toDouble();
                final left = anchorX - 36 * scale;
                return Positioned(
                  key: ValueKey('activity-$index'),
                  left: left,
                  top: y - verticalGap / 2,
                  width: width - left,
                  height: verticalGap,
                  child: IgnorePointer(
                    ignoring: categoryVisibility < 0.55 || opacity < 0.05,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => widget.onOpenActivity(index),
                      child: Semantics(
                        button: true,
                        selected: index == widget.selectedActivity,
                        label: index == widget.selectedActivity
                            ? '${XmbMenu.activityNames[index]}, Laboratory Activity ${index + 1}'
                            : XmbMenu.activityNames[index],
                        excludeSemantics: true,
                        child: Opacity(
                          opacity: opacity,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 72 * scale,
                                child: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        if (focus > 0.01)
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.24 * focus,
                                            ),
                                            blurRadius: 12 * scale,
                                          ),
                                      ],
                                    ),
                                    child: index < 2
                                        ? XmbIcon(
                                            kind: index == 0
                                                ? XmbIconKind.music
                                                : XmbIconKind.weather,
                                            size: (44 + 12 * focus) * scale,
                                            selected: focus > 0.5,
                                          )
                                        : Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // show hazard texture behind frame.
                                              Image.asset(
                                                'assets/images/hazard-stripes.png',
                                                width:
                                                    (44 + 12 * focus) * scale,
                                                height:
                                                    (44 + 12 * focus) * scale,
                                                fit: BoxFit.cover,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                              Image.asset(
                                                'assets/images/activity-icon.png',
                                                width:
                                                    (44 + 12 * focus) * scale,
                                                height:
                                                    (44 + 12 * focus) * scale,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 24 * scale),
                              Expanded(
                                child: SizedBox(
                                  height: 64 * scale,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: (18 - 14 * focus) * scale,
                                        child: Text(
                                          XmbMenu.activityNames[index],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: xmbTextStyle(
                                            fontSize * (0.88 + 0.12 * focus),
                                          ),
                                        ),
                                      ),
                                      if (index == widget.selectedActivity) ...[
                                        Positioned(
                                          left: 0,
                                          right: -48 * scale,
                                          top: 34 * scale,
                                          child: Opacity(
                                            opacity: focus,
                                            child: SizedBox(
                                              key: const ValueKey(
                                                'activity-divider',
                                              ),
                                              height: 2 * scale,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.42,
                                                          ),
                                                      blurRadius: 3 * scale,
                                                      offset: Offset(
                                                        0,
                                                        1 * scale,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 41 * scale,
                                          child: Opacity(
                                            opacity: focus,
                                            child: Text(
                                              'Laboratory Activity ${index + 1}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: xmbTextStyle(14.5 * scale),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // draw the clock and battery.
              Positioned(
                top: 8 * scale,
                right: 18 * scale,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.clockText, style: xmbTextStyle(21 * scale)),
                    SizedBox(width: 13 * scale),
                    XmbIcon(kind: XmbIconKind.battery, size: 39 * scale),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
