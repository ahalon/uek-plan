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
  bool groupsSynced = false;
  String? groupsError;

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

  Future<void> _fetchGroups() async {
    setState(() {
      isLoading = true;
      groupsError = null;
    });
    try {
      final all = await ApiService.fetchGroups();
      setState(() {
        deanGroups = all.where((g) => !g.isWf && !g.isLang).toList();
        langGroups = all.where((g) => g.isLang).toList();
        groupsSynced = true;
      });

      var box = Hive.box('uekBox');

      final savedDeanId = box.get('group_id');
      if (savedDeanId != null) {
        try {
          selectedDean = deanGroups.firstWhere((g) => g.id == savedDeanId);
        } catch (_) {}
      }

      final langsRaw = box.get('lang_groups_json');
      if (langsRaw != null) {
        try {
          List<dynamic> decodedLangs = json.decode(langsRaw);
          List<String> savedLangIds = decodedLangs
              .map((e) => e['id'].toString())
              .toList();
          selectedLangs = langGroups
              .where((g) => savedLangIds.contains(g.id))
              .toList();
        } catch (_) {}
      }

      final wfRaw = box.get('custom_wf_json');
      if (wfRaw != null) {
        try {
          customWf = json.decode(wfRaw);
        } catch (_) {}
      }
    } catch (e) {
      setState(() {
        groupsSynced = false;
        groupsError = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _save() async {
    if (selectedDean == null) return;

    var box = Hive.box('uekBox');

    await box.put('group_id', selectedDean!.id);
    await box.put('selected_dean_json', json.encode(selectedDean!.toJson()));

    final langsJson = selectedLangs.map((e) => e.toJson()).toList();
    await box.put('lang_groups_json', json.encode(langsJson));

    if (customWf != null) {
      await box.put('custom_wf_json', json.encode(customWf));
    } else {
      await box.delete('custom_wf_json');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const PlanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color tileBg = isDark ? Colors.white10 : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Konfiguracja"),
        actions: [
          ValueListenableBuilder(
            valueListenable: Hive.box(
              'uekBox',
            ).listenable(keys: ['is_dark_mode']),
            builder: (context, Box box, _) {
              return PopupMenuButton<bool>(
                icon: const Icon(Icons.dark_mode),
                tooltip: "Wybierz motyw",
                onSelected: (bool value) => box.put('is_dark_mode', value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: false, child: Text("Jasny motyw")),
                  const PopupMenuItem(value: true, child: Text("Ciemny motyw")),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              title: Text(selectedDean?.name ?? "Wybierz grupę dziekańską"),
              tileColor: tileBg,
              trailing: const Icon(Icons.search),
              onTap: () => _showDeanPicker(),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(
                selectedLangs.isEmpty
                    ? "Wybierz 2 lektoraty"
                    : "Lektoraty: ${selectedLangs.map((e) => e.name).join(', ')}",
              ),
              subtitle: Text(
                "Wybrano ${selectedLangs.length}/2",
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              tileColor: tileBg,
              trailing: const Icon(Icons.language),
              onTap: () => _showLangPicker(),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(
                customWf != null
                    ? "WF: ${customWf!['przedmiot']} (${customWf!['godzina']})"
                    : "Skonfiguruj WF ręcznie",
              ),
              tileColor: tileBg,
              trailing: const Icon(Icons.sports_basketball),
              onTap: () => _showWfFormModal(),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: isLoading ? null : _save,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Zapisz i przejdź do planu"),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLoading
                      ? Icons.sync
                      : groupsSynced
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 14,
                  color: isLoading
                      ? Colors.orange
                      : groupsSynced
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 5),
                Text(
                  isLoading
                      ? "Aktualizacja bazy grup..."
                      : groupsSynced
                      ? "Baza grup zsynchronizowana"
                      : "Nie udało się zsynchronizować grup",
                  style: TextStyle(
                    fontSize: 12,
                    color: isLoading
                        ? Colors.orange
                        : groupsSynced
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeanPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(10),
        child: deanGroups.isEmpty
            ? (isLoading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          "Pobieranie grup z serwera UEK...",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Może to potrwać do 20 sekund.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    )
                  : (groupsError != null)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          const Text("Nie udało się pobrać grup"),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _fetchGroups();
                            },
                            child: const Text("Spróbuj ponownie"),
                          ),
                        ],
                      ),
                    )
                  : const Center(child: Text("Brak grup do wyświetlenia")))
            : SearchableList<UekGroup>(
                initialList: deanGroups,
                itemBuilder: (item) => ListTile(
                  title: Text(item.name),
                  onTap: () {
                    setState(() => selectedDean = item);
                    Navigator.pop(context);
                  },
                ),
                filter: (value) => deanGroups
                    .where(
                      (e) => e.name.toLowerCase().contains(value.toLowerCase()),
                    )
                    .toList(),
              ),
      ),
    );
  }

  void _showLangPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(10),
          child: langGroups.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        "Wybierz 2 lektoraty",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "Wybrano ${selectedLangs.length}/2",
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SearchableList<UekGroup>(
                        initialList: langGroups,
                        itemBuilder: (item) => CheckboxListTile(
                          title: Text(item.name),
                          value: selectedLangs.any((e) => e.id == item.id),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                final alreadySelected = selectedLangs.any(
                                  (e) => e.id == item.id,
                                );
                                if (!alreadySelected &&
                                    selectedLangs.length >= 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Możesz wybrać maksymalnie 2 lektoraty.",
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (!alreadySelected) {
                                  selectedLangs.add(item);
                                }
                              } else {
                                selectedLangs.removeWhere(
                                  (e) => e.id == item.id,
                                );
                              }
                            });
                            setState(() {});
                          },
                        ),
                        filter: (value) => langGroups
                            .where(
                              (e) => e.name.toLowerCase().contains(
                                value.toLowerCase(),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showWfFormModal() {
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Ręczny wpis WF",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  initialValue: wfDay,
                  decoration: const InputDecoration(
                    labelText: "Dzień tygodnia",
                    border: OutlineInputBorder(),
                  ),
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
                TextField(
                  controller: wfTimeCtrl,
                  decoration: const InputDecoration(
                    labelText: "Godziny (np. 11:30 - 13:00)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: wfNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nazwa (np. Basen, Koszykówka)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: wfRoomCtrl,
                  decoration: const InputDecoration(
                    labelText: "Sala (np. Hala)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: wfTeacherCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nauczyciel",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => customWf = null);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Usuń WF",
                        style: TextStyle(color: Colors.red),
                      ),
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
