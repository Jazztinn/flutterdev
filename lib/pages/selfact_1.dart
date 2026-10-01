import 'package:flutter/material.dart';

import 'activity_placeholder.dart';

// show the self activity page.
class SelfActivityOnePage extends ActivityPlaceholderPage {
  const SelfActivityOnePage({super.key, required super.title})
    : super(
        message:
            'This self activity is still under development. Please wait...',
        fontFamily: 'Century Gothic',
        textAlign: TextAlign.center,
      );
}
