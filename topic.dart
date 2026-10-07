import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'test_exam.dart';

const String apiBaseUrl = 'http://10.0.2.2:8000';

class Topic {
  final String id, subject, topicName;
  Topic({required this.id, required this.subject, required this.topicName});
  factory Topic.fromJson(Map<String, dynamic> json) => Topic(id: json['id'], subject: json['subject'], topicName: json['topic_name']);
}

class TopicScreen extends StatefulWidget {
  final String classLevel;
  const TopicScreen({super.key, required this.classLevel});
  @override State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  bool loading = true;
  String? error;
  List<Topic> topics = [];
  final Set<String> selected = {};

  @override void initState() { super.initState(); loadTopics(); }

  Future<void> loadTopics() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/topics?class_level=${widget.classLevel}'));
      if (response.statusCode != 200) throw Exception('Unable to load topics');
      final data = jsonDecode(response.body) as List;
      setState(() { topics = data.map((x) => Topic.fromJson(x)).toList(); loading = false; });
    } catch (e) { setState(() { loading = false; error = e.toString(); }); }
  }

  Map<String, List<Topic>> groupedTopics() {
    final result = <String, List<Topic>>{};
    for (final t in topics) result.putIfAbsent(t.subject, () => []).add(t);
    return result;
  }

  Future<void> generateTest() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one topic')));
      return;
    }
    final response = await http.post(Uri.parse('$apiBaseUrl/api/generate-test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'class_level': widget.classLevel, 'topic_ids': selected.toList(), 'difficulty': 'Medium', 'question_count': 10}));
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation failed: ${response.body}')));
      return;
    }
    if (!mounted) return;
    final result = jsonDecode(response.body);
    Navigator.push(context, MaterialPageRoute(builder: (_) => TestExamScreen(questions: result['questions'])));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Topics')),
      body: loading ? const Center(child: CircularProgressIndicator()) :
      error != null ? Center(child: Text(error!)) :
      Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: groupedTopics().entries.map((entry) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text(entry.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          ...entry.value.map((topic) => CheckboxListTile(
            value: selected.contains(topic.id), title: Text(topic.topicName),
            onChanged: (v) => setState(() { if (v == true) selected.add(topic.id); else selected.remove(topic.id); }),
          )),
        ])).toList())),
        SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 52,
          child: FilledButton(onPressed: generateTest, child: const Text('Generate Mock Test'))))),
      ]),
    );
  }
}
