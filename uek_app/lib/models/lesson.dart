class Lesson {
  final String data;
  final String godzina;
  final String przedmiot;
  final String typ;
  final String nauczyciel;
  final String sala;
  final String uwagi;
  final int? customDay;

  Lesson({
    required this.data,
    required this.godzina,
    required this.przedmiot,
    required this.typ,
    required this.nauczyciel,
    required this.sala,
    required this.uwagi,
    this.customDay,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      data: json['data']?.toString() ?? '',
      godzina: json['godzina']?.toString() ?? '',
      przedmiot: json['przedmiot']?.toString() ?? '',
      typ: json['typ']?.toString() ?? '',
      nauczyciel: json['nauczyciel']?.toString() ?? '',
      sala: json['sala']?.toString() ?? '',
      uwagi: json['uwagi']?.toString() ?? '',
      customDay: json['day'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data,
        'godzina': godzina,
        'przedmiot': przedmiot,
        'typ': typ,
        'nauczyciel': nauczyciel,
        'sala': sala,
        'uwagi': uwagi,
        if (customDay != null) 'day': customDay,
      };
}