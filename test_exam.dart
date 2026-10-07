import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'http://10.0.2.2:8000';

enum QuestionStatus { notVisited, answered, marked, answeredMarked }

class TestExamScreen extends StatefulWidget {
  final List<dynamic> questions;
  const TestExamScreen({super.key, required this.questions});
  @override State<TestExamScreen> createState() => _TestExamScreenState();
}

class _TestExamScreenState extends State<TestExamScreen> {
  int currentIndex = 0, secondsRemaining = 1800;
  Timer? timer;
  final Map<int, String> answers = {};
  final Set<int> marked = {}, visited = {};

  @override void initState() {
    super.initState();
    if (widget.questions.isNotEmpty) visited.add(0);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsRemaining <= 0) { timer?.cancel(); submitTest(); }
      else setState(() => secondsRemaining--);
    });
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  String get timeText => '${(secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(secondsRemaining % 60).toString().padLeft(2, '0')}';

  QuestionStatus statusFor(int i) {
    final a = answers.containsKey(i), m = marked.contains(i);
    if (a && m) return QuestionStatus.answeredMarked;
    if (a) return QuestionStatus.answered;
    if (m) return QuestionStatus.marked;
    return QuestionStatus.notVisited;
  }

  void selectQuestion(int i) => setState(() { currentIndex = i; visited.add(i); });
  void chooseAnswer(String option) => setState(() => answers[currentIndex] = option);
  void toggleMark() => setState(() { marked.contains(currentIndex) ? marked.remove(currentIndex) : marked.add(currentIndex); });

  Future<void> submitTest() async {
    timer?.cancel();
    final payload = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.questions.length; i++) {
      payload.add({'question_id': widget.questions[i]['id'], 'selected_option': answers[i]});
    }
    final response = await http.post(Uri.parse('$apiBaseUrl/api/submit-test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'answers': payload, 'time_taken': 1800 - secondsRemaining}));
    if (!mounted) return;
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: ${response.body}')));
      return;
    }
    final r = jsonDecode(response.body);
    await showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text('Test Submitted'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${r['score']}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
        const Text('Score'), const SizedBox(height: 20),
        Text('Correct: ${r['correct']}'), Text('Wrong: ${r['wrong']}'), Text('Unanswered: ${r['unanswered']}'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), child: const Text('Done'))],
    ));
  }

  Widget buildPalette() => GridView.builder(
    shrinkWrap: true, itemCount: widget.questions.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
    itemBuilder: (_, i) {
      final status = statusFor(i);
      final color = status == QuestionStatus.answered ? Colors.green :
          status == QuestionStatus.marked ? Colors.orange :
          status == QuestionStatus.answeredMarked ? Colors.deepPurple : Colors.grey.shade300;
      return InkWell(onTap: () => selectQuestion(i), child: Container(
        alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: status == QuestionStatus.notVisited ? Colors.black : Colors.white)),
      ));
    });

  @override Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const Scaffold(body: Center(child: Text('No questions generated.')));
    final q = widget.questions[currentIndex];
    final options = {'A': q['options']['A'], 'B': q['options']['B'], 'C': q['options']['C'], 'D': q['options']['D']};
    return Scaffold(
      appBar: AppBar(title: Text('Question ${currentIndex + 1}/${widget.questions.length}'), actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: Text(timeText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))))]),
      drawer: Drawer(child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Question Palette', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20), buildPalette(), const SizedBox(height: 20),
        const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('Grey — Not Visited'), const Text('Green — Answered'), const Text('Orange — Marked for Review'), const Text('Purple — Answered & Marked'),
      ]))),
      body: Column(children: [
        LinearProgressIndicator(value: (currentIndex + 1) / widget.questions.length),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${q['subject']} • ${q['difficulty']}', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          Text(q['question_text'], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 25),
          ...options.entries.where((e) => e.value != null).map((e) => Card(child: RadioListTile<String>(
            value: e.key, groupValue: answers[currentIndex], onChanged: (_) => chooseAnswer(e.key), title: Text('${e.key}. ${e.value}'),
          ))),
        ]))),
        SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: currentIndex == 0 ? null : () => selectQuestion(currentIndex - 1), child: const Text('Previous'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: toggleMark, child: const Text('Mark'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: currentIndex == widget.questions.length - 1 ? submitTest : () => selectQuestion(currentIndex + 1), child: Text(currentIndex == widget.questions.length - 1 ? 'Submit' : 'Next'))),
        ]))),
      ]),
    );
  }
}
