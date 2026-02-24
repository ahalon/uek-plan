import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uek_app/models/uek_group.dart';
import 'package:uek_app/services/api_service.dart';
import 'package:uek_app/screens/plan_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  List<UekGroup> deanGroups = [];
  List<UekGroup> langGroups = [];

  UekGroup? selectedDean;
  List<UekGroup> selectedLangs = [];
  Map<String, dynamic>? customWf;

  bool isLoading = false;

  final wfNameCtrl = TextEditingController();
  final wfTimeCtrl = TextEditingController();
  final wfRoomCtrl = TextEditingController();
  final wfTeacherCtrl = TextEditingController();
  int wfDay = 1; 

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  _fetchGroups() async {
    setState(() => isLoading = true);
    try {
      final all = await ApiService.fetchGroups();
      setState(() {
        deanGroups = all.where((g) => !g.isWf && !g.isLang).toList();
        langGroups = all.where((g) => g.isLang).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  _save() async {
    if (selectedDean == null) return;
    
    var box = Hive.box('uekBox');
    
    await box.put('group_id', selectedDean!.id);

    final langsJson = selectedLangs.map((e) => e.toJson()).toList();
    await box.put('lang_groups_json', json.encode(langsJson));

    if (customWf != null) {
      await box.put('custom_wf_json', json.encode(customWf));
    } else {
      await box.delete('custom_wf_json');
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
              title: Text(selectedDean?.name ?? "Wybierz grupę dziekańską"),
              tileColor: Colors.grey[200],
              trailing: const Icon(Icons.search),
              onTap: () => _showDeanPicker(),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(selectedLangs.isEmpty ? "Wybierz lektoraty" : "Wybrane: ${selectedLangs.map((e) => e.name).join(', ')}"),
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
        child: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SearchableList<UekGroup>(
              initialList: deanGroups,
              itemBuilder: (item) => ListTile(
                title: Text(item.name),
                onTap: () {
                  setState(() => selectedDean = item);
                  Navigator.pop(context);
                },
              ),
              filter: (value) => deanGroups.where((e) => e.name.toLowerCase().contains(value.toLowerCase())).toList(),
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
                child: SearchableList<UekGroup>(
                  initialList: langGroups,
                  itemBuilder: (item) => CheckboxListTile(
                    title: Text(item.name),
                    value: selectedLangs.any((e) => e.id == item.id),
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedLangs.add(item);
                        } else {
                          selectedLangs.removeWhere((e) => e.id == item.id);
                        }
                      });
                      setState(() {});
                    },
                  ),
                  filter: (value) => langGroups.where((e) => e.name.toLowerCase().contains(value.toLowerCase())).toList(),
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
      wfNameCtrl.text = customWf!['przedmiot'].replaceAll('WF - ', '') ?? '';
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