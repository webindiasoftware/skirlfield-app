import 'package:flutter/material.dart';

import '../theme.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.text});
  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              const Text('Coming soon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            ]),
          ),
        ),
      );
}
