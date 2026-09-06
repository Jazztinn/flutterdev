import 'package:flutter/material.dart';

class SelfActivityOnePage extends StatelessWidget {
  const SelfActivityOnePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text(
          'This self activity is still under development. Please wait...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Century Gothic',
          ),
        ),
      ),
    );
  }
}
