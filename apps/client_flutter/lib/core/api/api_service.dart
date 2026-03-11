import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app/config.dart';

class ApiService {
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message']?.toString() ?? 'Giris basarisiz');
    }

    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'display_name': displayName.trim(),
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message']?.toString() ?? 'Kayit basarisiz');
    }

    return data;
  }

  static Future<List<dynamic>> getTables() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/tables'),
      headers: {'Content-Type': 'application/json'},
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message']?.toString() ?? 'Masa listesi alinamadi');
    }

    return (data['tables'] as List?) ?? [];
  }
}
