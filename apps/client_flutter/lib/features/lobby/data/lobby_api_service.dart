import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../app/config.dart';
import '../domain/game_table.dart';

class LobbyApiService {
  Future<List<GameTable>> fetchTables() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/tables');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Masalar alinamadi: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded
          .map((e) => GameTable.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Beklenmeyen tables response formati');
  }

  Future<Map<String, dynamic>> joinTable({
    required int tableId,
    required int userId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/tables/$tableId/join');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Masaya katilinamadi: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
