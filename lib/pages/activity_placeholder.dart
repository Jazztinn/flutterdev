import 'package:flutter/material.dart';

class ActivityPlaceholderPage extends StatelessWidget {
  const ActivityPlaceholderPage({
    super.key,
    required this.title,
    this.message = 'This page is still under development. Please wait...',
    this.fontFamily,
    this.textAlign,
    this.showConstructionImage = false,
  });

  final String title;
  final String message;
  final String? fontFamily;
  final TextAlign? textAlign;
  final bool showConstructionImage;

  @override
  // show a simple placeholder page.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showConstructionImage) ...[
              Image.asset(
                'assets/images/construction-worker.gif',
                key: const ValueKey('construction-worker'),
                width: 180,
                height: 210,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: textAlign,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
