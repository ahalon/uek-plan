import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:searchable_listview/searchable_listview.dart';

// ZMIEŃ TO NA SWOJE IP:
const String serverIp = "192.168.1.116";

void main() => runApp(MaterialApp(
      home: const StartCheck(),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6366f1)),
      debugShowCheckedModeBanner: false,
    ));

class StartCheck extends StatefulWidget {
  const StartCheck({super.key});
  @override
  State<StartCheck> createState() => _StartCheckState();
}

class _StartCheckState extends State<StartCheck> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  _check() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('group_id');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => (id != null) ? const PlanScreen() : const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  List<dynamic> groups = [];
  String? selectedId;
  String? selectedName;
  final langController = TextEditingController();
  final wfController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  _fetchGroups() async {
    try {
      final res = await http.get(Uri.parse('http://$serverIp:8000/groups'));
      if (res.statusCode == 200) setState(() => groups = json.decode(res.body));
    } catch (e) { print(e); }
  }

  _save() async {
    if (selectedId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_id', selectedId!);
    await prefs.setString('lang_group', langController.text.trim().toUpperCase());
    await prefs.setString('wf_group', wfController.text.trim().toUpperCase());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PlanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konfiguracja")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              title: Text(selectedName ?? "Wybierz grupę dziekańską"),
              tileColor: Colors.grey[200],
              trailing: const Icon(Icons.search),
              onTap: () => _showGroupPicker(),
            ),
            const SizedBox(height: 15),
            TextField(controller: langController, decoration: const InputDecoration(labelText: "Grupa językowa (np. S11)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: wfController, decoration: const InputDecoration(labelText: "Grupa WF (np. GR. 4)", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            ElevatedButton(onPressed: _save, child: const Text("Zapisz i przejdź do planu"))
          ],
        ),
      ),
    );
  }

  _showGroupPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(10),
        child: SearchableList<dynamic>(
          initialList: groups,
          itemBuilder: (item) => ListTile(
            title: Text(item['name']),
            onTap: () {
              setState(() {
                selectedName = item['name'];
                selectedId = item['id'];
              });
              Navigator.pop(context);
            },
          ),
          filter: (value) => groups.where((e) => e['name'].toLowerCase().contains(value.toLowerCase())).toList(),
          inputDecoration: const InputDecoration(labelText: "Szukaj grupy..."),
        ),
      ),
    );
  }
}

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Map<String, List<dynamic>> plan = {};
  DateTime selectedDate = DateTime.now();
  bool loading = false;

  @override
  void initState() { super.initState(); loadPlan(); }

  loadPlan() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('group_id');
    final lang = prefs.getString('lang_group') ?? "";
    final wf = prefs.getString('wf_group') ?? "";
    
    try {
      final res = await http.get(Uri.parse('http://$serverIp:8000/plan/$id'));
      if (res.statusCode == 200) {
        List<dynamic> data = json.decode(res.body);
        final filtered = data.where((l) {
          final p = l['przedmiot'].toString().toLowerCase();
          final t = l['typ'].toString().toLowerCase();
          if (p.contains("język") || t.contains("lektorat")) return p.contains(lang.toLowerCase());
          if (p.contains("wf") || p.contains("wychowanie fizyczne")) return p.contains(wf.toLowerCase());
          return true;
        }).toList();
        setState(() => plan = groupBy(filtered, (dynamic e) => e['data']?.toString() ?? ''));
      }
    } catch (e) { print(e); }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    String key = DateFormat('yyyy-MM-dd').format(selectedDate);
    List<dynamic> dayPlan = plan[key] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("Plan UEK"), actions: [
        IconButton(icon: const Icon(Icons.settings), onPressed: () async {
          (await SharedPreferences.getInstance()).clear();
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SetupScreen()));
        })
      ]),
      body: Column(
        children: [
          EasyDateTimeLine(
            initialDate: DateTime.now(),
            onDateChange: (d) => setState(() => selectedDate = d),
            headerProps: const EasyHeaderProps(monthPickerType: MonthPickerType.switcher),
          ),
          Expanded(
            child: loading 
              ? const Center(child: CircularProgressIndicator()) 
              : dayPlan.isEmpty 
                ? const Center(child: Text("Brak zajęć"))
                : ListView.builder(
                    itemCount: dayPlan.length,
                    itemBuilder: (context, i) => _card(dayPlan[i]),
                  ),
          )
        ],
      ),
    );
  }

  Widget _card(dynamic l) {
    bool isW = l['typ'].toString().toLowerCase().contains('wykład');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isW ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l['godzina'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l['typ'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(l['przedmiot'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Text("Sala: ${l['sala']}"),
        ],
      ),
    );
  }
}