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
  List<dynamic> selectedLangs = [];
  Map<String, dynamic>? customWf;

  bool isLoading = false;

  final wfNameCtrl = TextEditingController();
  final wfTimeCtrl = TextEditingController();
  final wfRoomCtrl = TextEditingController();
  final wfTeacherCtrl = TextEditingController();
  int wfDay = 1; // 1 = Poniedziałek, 7 = Niedziela

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
          // Filtrujemy tylko grupy dziekańskie i języki. WF z backendu nas już nie interesuje.
          deanGroups = all.where((g) => g['is_wf'] == false && g['is_lang'] == false).toList();
          langGroups = all.where((g) => g['is_lang'] == true).toList();
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
    await prefs.setString('lang_groups_json', json.encode(selectedLangs));

    if (customWf != null) {
      await prefs.setString('custom_wf_json', json.encode(customWf));
    } else {
      await prefs.remove('custom_wf_json');
    }

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
              title: Text(selectedLangs.isEmpty ? "Wybierz lektoraty" : "Wybrane: ${selectedLangs.map((e) => e['name']).join(', ')}"),
              tileColor: Colors.grey[200],
              trailing: const Icon(Icons.language),
              onTap: () => _showLangPicker(),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(customWf != null ? "WF: ${customWf!['przedmiot']} (${customWf!['godzina']})" : "Skonfiguruj WF ręcznie"),
              tileColor: Colors.grey[200],
              trailing: const Icon(Icons.sports_basketball),
              onTap: () => _showWfFormModal(),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: _save,
                child: const Text("Zapisz i przejdź do planu"))
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
                    value: selectedLangs.any((e) => e['id'] == item['id']),
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedLangs.add(item);
                        } else {
                          selectedLangs.removeWhere((e) => e['id'] == item['id']);
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

  _showWfFormModal() {
    if (customWf != null) {
      wfNameCtrl.text = customWf!['przedmiot'] ?? '';
      wfTimeCtrl.text = customWf!['godzina'] ?? '';
      wfRoomCtrl.text = customWf!['sala'] ?? '';
      wfTeacherCtrl.text = customWf!['nauczyciel'] ?? '';
      wfDay = customWf!['day'] ?? 1;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Ręczny wpis WF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  value: wfDay,
                  decoration: const InputDecoration(labelText: "Dzień tygodnia", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Poniedziałek")),
                    DropdownMenuItem(value: 2, child: Text("Wtorek")),
                    DropdownMenuItem(value: 3, child: Text("Środa")),
                    DropdownMenuItem(value: 4, child: Text("Czwartek")),
                    DropdownMenuItem(value: 5, child: Text("Piątek")),
                  ],
                  onChanged: (val) => setModalState(() => wfDay = val!),
                ),
                const SizedBox(height: 10),
                TextField(controller: wfTimeCtrl, decoration: const InputDecoration(labelText: "Godziny (np. 11:30 - 13:00)", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: wfNameCtrl, decoration: const InputDecoration(labelText: "Nazwa (np. Basen, Koszykówka)", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: wfRoomCtrl, decoration: const InputDecoration(labelText: "Sala (np. Pawilon Sportowy)", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: wfTeacherCtrl, decoration: const InputDecoration(labelText: "Nauczyciel", border: OutlineInputBorder())),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => customWf = null);
                        Navigator.pop(context);
                      },
                      child: const Text("Usuń WF", style: TextStyle(color: Colors.red)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          customWf = {
                            'day': wfDay,
                            'godzina': wfTimeCtrl.text.trim(),
                            'przedmiot': "WF - ${wfNameCtrl.text.trim()}",
                            'sala': wfRoomCtrl.text.trim(),
                            'nauczyciel': wfTeacherCtrl.text.trim(),
                            'typ': 'ćwiczenia',
                          };
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Zapisz"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
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
  Map<String, dynamic>? customWf;
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
    final deanId = prefs.getString('group_id');

    final langsRaw = prefs.getString('lang_groups_json') ?? "[]";
    final List<dynamic> myLangs = json.decode(langsRaw);

    final customWfRaw = prefs.getString('custom_wf_json');
    if (customWfRaw != null) {
      customWf = json.decode(customWfRaw);
    }

    List<dynamic> allPlan = [];

    try {
      if (deanId != null) {
        final resDean = await http.get(Uri.parse('http://$serverIp:8000/plan/$deanId'));
        if (resDean.statusCode == 200) {
          List<dynamic> deanData = json.decode(resDean.body);

          final filteredDean = deanData.where((item) {
            final s = item['sala'].toString().toUpperCase();
            final p = item['przedmiot'].toString().toUpperCase();

            // Wypieprzamy z dziekańskiego ogólnikowe wpisy o lektoratach i wuefach
            if (s.contains("WYBIERZ SWOJĄ GRUPĘ")) return false;
            if (p.contains("WYCHOWANIE FIZYCZNE") || p.contains("WF ") || p.contains("AZS")) return false;

            return true;
          }).toList();

          allPlan.addAll(filteredDean);
        }
      }

      for (var lang in myLangs) {
        final resLang = await http.get(Uri.parse('http://$serverIp:8000/plan/${lang['id']}'));
        if (resLang.statusCode == 200) {
          allPlan.addAll(json.decode(resLang.body));
        }
      }

      if (mounted) {
        setState(() {
          plan = groupBy(allPlan, (dynamic e) => e['data']?.toString() ?? '');
        });
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
    
    // Zabezpieczenie na brak godziny, by aplikacja się nie sypnęła
    sortedPlan.sort((a, b) {
      String aStart = _cleanTime(a['godzina']?.toString().split('-')[0] ?? "00:00");
      String bStart = _cleanTime(b['godzina']?.toString().split('-')[0] ?? "00:00");
      return aStart.compareTo(bStart);
    });

    for (int i = 0; i < sortedPlan.length; i++) {
      list.add(_card(sortedPlan[i]));

      if (i < sortedPlan.length - 1) {
        try {
          String fullTime = sortedPlan[i]['godzina'].toString();
          String nextFullTime = sortedPlan[i + 1]['godzina'].toString();

          if (fullTime.contains('-') && nextFullTime.contains('-')) {
            String currentEndStr = _cleanTime(fullTime.split('-')[1]);
            String nextStartStr = _cleanTime(nextFullTime.split('-')[0]);

            DateFormat format = DateFormat("HH:mm");
            DateTime currentEnd = format.parse(currentEndStr);
            DateTime nextStart = format.parse(nextStartStr);

            int diffInMinutes = nextStart.difference(currentEnd).inMinutes;

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
    // 1. Wyciągamy zajęcia z backendu dla danej daty
    List<dynamic> dayPlan = List.from(plan[key] ?? []);

    // 2. Wstrzykujemy ręczny WF, jeśli zgadza się dzień tygodnia
    if (customWf != null && selectedDate.weekday == customWf!['day']) {
      dayPlan.add(customWf);
    }

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
          
          // Wyświetlanie nauczyciela, jeśli został dodany (WF z palca) lub backend to wypluwa
          if (l['nauczyciel'] != null && l['nauczyciel'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(l['nauczyciel'], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
              ],
            ),
          ],
          
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text("Sala: ${l['sala']}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }
}