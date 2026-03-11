import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../app/config.dart';

class GameApiService {
  Future<Map<String, dynamic>> startGame({
    required int tableId,
    required int userId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/games/start');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'table_id': tableId,
        'user_id': userId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Oyun baslatilamadi: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchGame({
    required int gameId,
    required int viewerUserId,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/games/$gameId?viewer_user_id=$viewerUserId',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Oyun verisi alinamadi: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> drawTile({
    required int gameId,
    required int userId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/games/$gameId/draw');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Tas cekilemedi: ${response.body}');
    }
  }

  Future<void> discardTile({
    required int gameId,
    required int userId,
    required String tileId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/games/$gameId/discard');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'tile_id': tileId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Tas atilamadi: ${response.body}');
    }
  }

  Future<void> openHand({
    required int gameId,
    required int userId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/games/$gameId/open');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('El acilamadi: ${response.body}');
    }
  }

  Future<void> runBotTurns({
    required int gameId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/games/$gameId/bot-turns');

    final response = await http.post(uri);

    if (response.statusCode != 200) {
      throw Exception('Bot turlari calistirilamadi: ${response.body}');
    }
  }
}
