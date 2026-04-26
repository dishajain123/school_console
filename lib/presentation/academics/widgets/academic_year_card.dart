import 'package:flutter/material.dart';

class AcademicYearCard extends StatelessWidget {
  const AcademicYearCard({super.key, this.title = 'Academic Year'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(title)),
    );
  }
}
