import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:intl/intl.dart';
import 'package:uek_app/models/lesson.dart';
import 'package:uek_app/services/api_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uek_app/widgets/lesson_card.dart';
import 'package:uek_app/screens/setup_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Map<String, List<Lesson>> plan = {};
  Lesson? customWf;
  DateTime selectedDate = DateTime.now();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadPlan();
  }

  Future<void> loadPlan() async {
    if (!mounted) return;
    var box = Hive.box('uekBox');

    final cachedPlan = box.get('cached_plan');
    if (cachedPlan != null) {
      try {
        List<dynamic> savedPlan = json.decode(cachedPlan);
        List<Lesson> parsed = savedPlan.map((e) => Lesson.fromJson(e)).toList();
        setState(() {
          plan = groupBy(parsed, (Lesson e) => e.data);
          loading = false;
        });
      } catch (e) {
        setState(() => loading = true);
      }
    } else {
      setState(() => loading = true);
    }

    try {
      final deanId = box.get('group_id');
      final langsRaw = box.get('lang_groups_json') ?? "[]";
      final List<dynamic> myLangs = json.decode(langsRaw);

      final customWfRaw = box.get('custom_wf_json');
      if (customWfRaw != null) {
        customWf = Lesson.fromJson(json.decode(customWfRaw));
      }

      List<Lesson> allPlan = [];

      if (deanId != null) {
        final deanData = await ApiService.fetchPlan(deanId);
        final filteredDean = deanData.where((item) {
          final s = item.sala.toUpperCase();
          final p = item.przedmiot.toUpperCase();
          if (s.contains("WYBIERZ SWOJĄ GRUPĘ")) return false;
          if (p.contains("WYCHOWANIE FIZYCZNE") ||
              p.contains("WF ") ||
              p.contains("AZS")) {
            return false;
          }
          return true;
        }).toList();
        allPlan.addAll(filteredDean);
      }

      for (var lang in myLangs) {
        final langData = await ApiService.fetchPlan(lang['id'].toString());
        allPlan.addAll(langData);
      }

      if (allPlan.isNotEmpty) {
        final jsonList = allPlan.map((e) => e.toJson()).toList();
        await box.put('cached_plan', json.encode(jsonList));
        if (mounted) {
          setState(() {
            plan = groupBy(allPlan, (Lesson e) => e.data);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Brak połączenia, używam danych offline"),
          ),
        );
      }
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

  List<Widget> _buildTimeline(List<Lesson> dayPlan) {
    List<Widget> list = [];
    List<Lesson> sortedPlan = List.from(dayPlan);

    sortedPlan.sort((a, b) {
      String aStart = _cleanTime(a.godzina.split('-')[0]);
      String bStart = _cleanTime(b.godzina.split('-')[0]);
      return aStart.compareTo(bStart);
    });

    for (int i = 0; i < sortedPlan.length; i++) {
      list.add(LessonCard(lesson: sortedPlan[i]));

      if (i < sortedPlan.length - 1) {
        try {
          String fullTime = sortedPlan[i].godzina;
          String nextFullTime = sortedPlan[i + 1].godzina;

          if (fullTime.contains('-') && nextFullTime.contains('-')) {
            String currentEndStr = _cleanTime(fullTime.split('-')[1]);
            String nextStartStr = _cleanTime(nextFullTime.split('-')[0]);

            DateTime currentEnd = DateFormat("HH:mm").parse(currentEndStr);
            DateTime nextStart = DateFormat("HH:mm").parse(nextStartStr);

            int diffInMinutes = nextStart.difference(currentEnd).inMinutes;

            if (diffInMinutes > 15) {
              list.add(
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          indent: 30,
                          endIndent: 10,
                          thickness: 0.5,
                        ),
                      ),
                      Text(
                        "Przerwa ${_formatDuration(diffInMinutes)}",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          indent: 10,
                          endIndent: 30,
                          thickness: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
        } catch (_) {}
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    String key = DateFormat('yyyy-MM-dd').format(selectedDate);
    List<Lesson> currentDayPlan = List.from(plan[key] ?? []);

    if (customWf != null && selectedDate.weekday == customWf!.customDay) {
      currentDayPlan.add(customWf!);
    }

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan UEK"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => const SetupScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          EasyInfiniteDateTimeLine(
            firstDate: DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
            focusDate: selectedDate,
            lastDate: DateTime(2030, 12, 31),
            onDateChange: (d) => setState(() => selectedDate = d),
            showTimelineHeader: true,
            dayProps: EasyDayProps(
              inactiveDayStyle: DayStyle(
                dayNumStyle: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                dayStrStyle: TextStyle(color: textColor),
                monthStrStyle: TextStyle(color: textColor),
              ),
              activeDayStyle: DayStyle(
                dayNumStyle: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                dayStrStyle: TextStyle(color: textColor),
                monthStrStyle: TextStyle(color: textColor),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isDark ? Colors.white24 : Colors.black12,
                      isDark ? Colors.white10 : Colors.black26,
                    ],
                  ),
                ),
              ),
              todayStyle: DayStyle(
                dayNumStyle: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                dayStrStyle: TextStyle(color: textColor),
                monthStrStyle: TextStyle(color: textColor),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await loadPlan();
                    },
                    child: currentDayPlan.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.3,
                              ),
                              Center(
                                child: Text(
                                  "Brak zajęć na ten dzień",
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 20),
                            children: _buildTimeline(currentDayPlan),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
