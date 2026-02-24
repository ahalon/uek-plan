class UekGroup {
  final String id;
  final String name;
  final bool isWf;
  final bool isLang;

  UekGroup({
    required this.id,
    required this.name,
    required this.isWf,
    required this.isLang,
  });

  factory UekGroup.fromJson(Map<String, dynamic> json) {
    return UekGroup(
      id: json['id'].toString(),
      name: json['name'].toString(),
      isWf: json['is_wf'] ?? false,
      isLang: json['is_lang'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_wf': isWf,
        'is_lang': isLang,
      };
}