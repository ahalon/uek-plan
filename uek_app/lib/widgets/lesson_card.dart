import 'package:flutter/material.dart';
import '../models/lesson.dart';

class LessonCard extends StatelessWidget {
  final Lesson lesson;

  const LessonCard({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    String typ = lesson.typ.toLowerCase();
    bool isW = typ.contains('wykład');
    bool isMoved = typ.contains('przeniesienie') || typ.contains('odwołan');

    Color bgColor = const Color(0xFFFEF3C7);
    if (isMoved) {
      bgColor = const Color(0xFFFEE2E2);
    } else if (isW) {
      bgColor = const Color(0xFFD1FAE5);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lesson.godzina, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMoved ? Colors.red[800] : Colors.black)),
              Text(lesson.typ, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMoved ? Colors.red[800] : Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 10),
          Text(lesson.przedmiot, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isMoved ? Colors.red[900] : Colors.black)),
          if (lesson.nauczyciel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: isMoved ? Colors.red[400] : Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(lesson.nauczyciel, style: TextStyle(color: isMoved ? Colors.red[400] : Colors.grey, fontWeight: FontWeight.w500))),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: isMoved ? Colors.red[400] : Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(lesson.sala.isEmpty ? "Brak sali" : "Sala: ${lesson.sala}", style: TextStyle(color: isMoved ? Colors.red[400] : Colors.grey, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (lesson.uwagi.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(lesson.uwagi, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 14)),
          ]
        ],
      ),
    );
  }
}