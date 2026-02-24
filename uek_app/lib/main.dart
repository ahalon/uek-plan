import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uek_app/screens/setup_screen.dart';
import 'package:uek_app/screens/plan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  var box = await Hive.openBox('uekBox');

  String? groupId = box.get('group_id');

  runApp(MaterialApp(
    home: groupId != null ? const PlanScreen() : const SetupScreen(),
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6366f1)),
    debugShowCheckedModeBanner: false,
  ));
}