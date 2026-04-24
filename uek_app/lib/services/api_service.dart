import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/uek_group.dart';
import '../models/lesson.dart';

class ApiService {
  static const String serverIp = "136.112.232.190";
  static const String baseUrl = "https://uek-plan.onrender.com";

  static String _extractApiError(http.Response res) {
    try {
      final decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Błąd serwera: ${res.statusCode}';
  }

  static Future<List<UekGroup>> fetchGroups() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/groups'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        return data.map((json) => UekGroup.fromJson(json)).toList();
      }
      throw Exception(_extractApiError(res));
    } catch (e) {
      throw Exception('Błąd pobierania grup: $e');
    }
  }

  static Future<List<Lesson>> fetchPlan(String groupId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/plan/$groupId'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        return data.map((json) => Lesson.fromJson(json)).toList();
      }
      throw Exception(_extractApiError(res));
    } catch (e) {
      throw Exception('Błąd pobierania planu: $e');
    }
  }
}
