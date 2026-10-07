import 'package:flutter/material.dart';
import 'screens/cohort.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JeeMockApp());
}

class JeeMockApp extends StatelessWidget {
  const JeeMockApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JEE Mock Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, scaffoldBackgroundColor: const Color(0xfff5f7fb)),
      home: const CohortScreen(),
    );
  }
}
