import 'package:flutter/material.dart';
import 'topic.dart';

class CohortScreen extends StatelessWidget {
  const CohortScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cohorts = [
      {'title': 'Class 11th', 'value': '11th', 'icon': Icons.school_outlined},
      {'title': 'Class 12th', 'value': '12th', 'icon': Icons.menu_book_outlined},
      {'title': 'Dropper', 'value': 'dropper', 'icon': Icons.rocket_launch_outlined},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('JEE Mock Test', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          const Text('Select your preparation level', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Choose your JEE syllabus cohort to load the relevant topics.', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
          const SizedBox(height: 30),
          ...cohorts.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(classLevel: c['value'] as String))),
              child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
                CircleAvatar(radius: 28, child: Icon(c['icon'] as IconData, size: 28)),
                const SizedBox(width: 18),
                Expanded(child: Text(c['title'] as String, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right),
              ])),
            )),
          )),
        ]),
      )),
    );
  }
}
