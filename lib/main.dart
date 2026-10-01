import 'package:flutter/material.dart';

import 'home_page.dart';

// start the app.
void main() {
  runApp(const MainApp());
}

// hold app settings.
class MainApp extends StatelessWidget {
  const MainApp({super.key, this.soundPlayer});

  final XmbSoundPlayer? soundPlayer;

  @override
  // show the main screen.
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(soundPlayer: soundPlayer),
    );
  }
}
