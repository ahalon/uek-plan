import 'package:flutter/material.dart';
import '../models/lesson.dart';

class LessonCard extends StatelessWidget {
  final Lesson lesson;

  const LessonCard({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    String typ = lesson.typ.toLowerCase();
    String przedmiot = lesson.przedmiot.toLowerCase();

    bool isW = typ.contains('wykład');
    bool isLek = typ.contains('lektorat') || przedmiot.contains('język');
    bool isWf = typ.contains('wychowanie fizyczne') || przedmiot.contains('wf') || przedmiot.contains('azs');
    bool isMoved = typ.contains('przeniesienie') || typ.contains('odwołan');

    final regex = RegExp(r'[,-]?\s*cs gr \d+', caseSensitive: false);
    
    String cleanPrzedmiot = lesson.przedmiot.replaceAll(regex, '').trim();
    String cleanTyp = lesson.typ.replaceAll(regex, '').trim();
    String cleanUwagi = lesson.uwagi.replaceAll(regex, '').trim();

    Color bgColor = const Color(0xFFFFEDD5);
    if (isMoved) {
      bgColor = const Color(0xFFFEE2E2);
    } else if (isWf) {
      bgColor = const Color(0xFFF3E8FF);
    } else if (isLek) {
      bgColor = const Color(0xFFDBEAFE);
    } else if (isW) {
      bgColor = const Color(0xFFD1FAE5);
    }

    Color textColor = Colors.black;
    Color subTextColor = Colors.blueGrey;
    Color alertColor = Colors.red[800]!;

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
              Text(lesson.godzina, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMoved ? alertColor : textColor)),
              Text(cleanTyp, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMoved ? alertColor : subTextColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text(cleanPrzedmiot, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isMoved ? alertColor : textColor)),
          if (lesson.nauczyciel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: isMoved ? alertColor : subTextColor),
                const SizedBox(width: 4),
                Expanded(child: Text(lesson.nauczyciel, style: TextStyle(color: isMoved ? alertColor : subTextColor, fontWeight: FontWeight.w500))),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: isMoved ? alertColor : subTextColor),
              const SizedBox(width: 4),
              Expanded(child: Text(lesson.sala.isEmpty ? "Brak sali" : "Sala: ${lesson.sala}", style: TextStyle(color: isMoved ? alertColor : subTextColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (cleanUwagi.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(cleanUwagi, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 14)),
          ]
        ],
      ),
    );
  }
}