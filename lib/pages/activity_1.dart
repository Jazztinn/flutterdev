import 'package:flutter/material.dart';

class ActivityOnePage extends StatelessWidget {
  const ActivityOnePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text(
          'This page is still under development. Please wait...',
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
