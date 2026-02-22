import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:searchable_listview/searchable_listview.dart';

const String serverIp = "10.0.2.2"; 

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
  List<dynamic> deanGroups = [];
  List<dynamic> langGroups = [];
  String? selectedDeanId;
  String? selectedDeanName;
  List<String> selectedLangs = [];
  final wfController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  _fetchGroups() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('http://$serverIp:8000/groups'));
      if (res.statusCode == 200) {
        List<dynamic> all = json.decode(res.body);
        setState(() {
          deanGroups = all.where((g) {
            final n = g['name'].toString().toUpperCase();
            return !n.startsWith("CJ") && !n.contains("WF") && !n.contains("AZS");
          }).toList();
          langGroups = all.where((g) => g['name'].toString().toUpperCase().startsWith("CJ")).toList();
        });
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  _save() async {
    if (selectedDeanId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_id', selectedDeanId!);
    await prefs.setString('lang_group', selectedLangs.join(','));
    await prefs.setString('wf_group', wfController.text.trim().toUpperCase());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PlanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konfiguracja")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              title: Text(selectedDeanName ?? "Wybierz grupę dziekańską"),
              tileColor: Colors.grey[200],
              trailing: const Icon(Icons.search),
              onTap: () => _showDeanPicker(),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(selectedLangs.isEmpty ? "Wybierz lektoraty (np. S11)" : "Wybrane: ${selectedLangs.join(', ')}"),
              subtitle: const Text("Zaznacz grupy z listy"),
              tileColor: Colors.grey[200],
              trailing: const Icon(Icons.language),
              onTap: () => _showLangPicker(),
            ),
            const SizedBox(height: 15),
            TextField(controller: wfController, decoration: const InputDecoration(labelText: "Grupa WF (np. GR. 4)", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            ElevatedButton(onPressed: _save, child: const Text("Zapisz i przejdź do planu"))
          ],
        ),
      ),
    );
  }

  _showDeanPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(10),
        child: SearchableList<dynamic>(
          initialList: deanGroups,
          itemBuilder: (item) => ListTile(
            title: Text(item['name']),
            onTap: () {
              setState(() {
                selectedDeanName = item['name'];
                selectedDeanId = item['id'];
              });
              Navigator.pop(context);
            },
          ),
          filter: (value) => deanGroups.where((e) => e['name'].toLowerCase().contains(value.toLowerCase())).toList(),
        ),
      ),
    );
  }

  _showLangPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(10), child: Text("Wybierz lektoraty", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                child: SearchableList<dynamic>(
                  initialList: langGroups,
                  itemBuilder: (item) => CheckboxListTile(
                    title: Text(item['name']),
                    value: selectedLangs.contains(item['name']),
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedLangs.add(item['name']);
                        } else {
                          selectedLangs.remove(item['name']);
                        }
                      });
                      setState(() {});
                    },
                  ),
                  filter: (value) => langGroups.where((e) => e['name'].toLowerCase().contains(value.toLowerCase())).toList(),
                ),
              ),
            ],
          ),
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
  void initState() {
    super.initState();
    loadPlan();
  }

  loadPlan() async {
    if (!mounted) return;
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('group_id');
    final langRaw = prefs.getString('lang_group') ?? "";
    final List<String> myLangCodes = langRaw.split(',').where((s) => s.isNotEmpty).map((s) => s.split(' ').last.toUpperCase()).toList();
    final myWf = (prefs.getString('wf_group') ?? "").trim().toUpperCase();

    try {
      final res = await http.get(Uri.parse('http://$serverIp:8000/plan/$id'));
      if (res.statusCode == 200) {
        List<dynamic> data = json.decode(res.body);
        final filtered = data.where((item) {
          final p = item['przedmiot'].toString().toUpperCase();
          final t = item['typ'].toString().toUpperCase();
          final s = item['sala'].toString().toUpperCase();
          bool isLanguage = p.contains("LANGUAGE") || p.contains("JĘZYK") || t.contains("LEKTORAT") || p.contains("GERMAN") || p.contains("ENGLISH");
          bool isWf = p.contains("WF ") || p.contains("WYCHOWANIE FIZYCZNE") || p.contains("AZS");
          if (isLanguage) {
            if (myLangCodes.isEmpty) return false;
            return myLangCodes.any((code) => p.contains(code) || s.contains(code));
          }
          if (isWf) {
            if (myWf.isEmpty) return false;
            return p.contains(myWf) || s.contains(myWf);
          }
          return true;
        }).toList();

        if (mounted) {
          setState(() {
            plan = groupBy(filtered, (dynamic e) => e['data']?.toString() ?? '');
          });
        }
      }
    } catch (e) {
      print("Błąd: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  String _cleanTime(String time) {
    RegExp regExp = RegExp(r"(\d{2}:\d{2})");
    Match? match = regExp.firstMatch(time);
    return match?.group(0) ?? time.trim();
  }

  String _formatDuration(int minutes) {
    int hours = minutes ~/ 60;
    int remainingMinutes = minutes % 60;
    if (hours == 0) return "$remainingMinutes min";
    if (remainingMinutes == 0) return "$hours h";
    return "$hours h $remainingMinutes min";
  }

  List<Widget> _buildTimeline(List<dynamic> dayPlan) {
    List<Widget> list = [];
    List<dynamic> sortedPlan = List.from(dayPlan);
    sortedPlan.sort((a, b) {
      String aStart = _cleanTime(a['godzina'].toString().split('-')[0]);
      String bStart = _cleanTime(b['godzina'].toString().split('-')[0]);
      return aStart.compareTo(bStart);
    });

    for (int i = 0; i < sortedPlan.length; i++) {
      list.add(_card(sortedPlan[i]));

      if (i < sortedPlan.length - 1) {
        try {
          String fullTime = sortedPlan[i]['godzina'].toString();
          String nextFullTime = sortedPlan[i+1]['godzina'].toString();

          if (fullTime.contains('-') && nextFullTime.contains('-')) {
            String currentEndStr = _cleanTime(fullTime.split('-')[1]);
            String nextStartStr = _cleanTime(nextFullTime.split('-')[0]);

            DateFormat format = DateFormat("HH:mm");
            DateTime currentEnd = format.parse(currentEndStr);
            DateTime nextStart = format.parse(nextStartStr);

            int diffInMinutes = nextStart.difference(currentEnd).inMinutes;

            // Pokazuj tylko, jeśli przerwa jest dłuższa niż 15 minut
            if (diffInMinutes > 15) {
              list.add(
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(child: Divider(indent: 30, endIndent: 10, thickness: 0.5)),
                      Text(
                        "Przerwa ${_formatDuration(diffInMinutes)}",
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Expanded(child: Divider(indent: 10, endIndent: 30, thickness: 0.5)),
                    ],
                  ),
                ),
              );
            }
          }
        } catch (e) {
          print("Błąd czasu: $e");
        }
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    String key = DateFormat('yyyy-MM-dd').format(selectedDate);
    List<dynamic> dayPlan = plan[key] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("Plan UEK"), actions: [
        IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
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
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: _buildTimeline(dayPlan),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l['godzina'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(l['typ'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 10),
          Text(l['przedmiot'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text("Sala: ${l['sala']}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}