import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uek_app/screens/setup_screen.dart';
import 'package:uek_app/screens/plan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  var box = await Hive.openBox('uekBox');
  String? groupId = box.get('group_id');

  runApp(
    ValueListenableBuilder(
      valueListenable: box.listenable(keys: ['is_dark_mode']),
      builder: (context, Box box, _) {
        final bool isDark = box.get('is_dark_mode', defaultValue: false);
        
        return MaterialApp(
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF6366f1),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF6366f1),
            brightness: Brightness.dark,
          ),
          debugShowCheckedModeBanner: false,
          home: groupId != null ? const PlanScreen() : const SetupScreen(),
        );
      },
    ),
  );
}