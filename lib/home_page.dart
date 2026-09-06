import 'package:flutter/material.dart';

import 'pages/activity_1.dart';
import 'pages/activity_2.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Homepage')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _buildActivityButton(
              context,
              Icons.looks_one,
              'Activity 1',
              const ActivityOnePage(title: 'Activity 1'),
            ),
            _buildActivityButton(
              context,
              Icons.looks_two,
              'Activity 2',
              const ActivityTwoPage(title: 'Activity 2'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityButton(
    BuildContext context,
    IconData icon,
    String label,
    Widget page,
  ) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 24),
      label: Text(label),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => page),
        );
      },
    );
  }
}
