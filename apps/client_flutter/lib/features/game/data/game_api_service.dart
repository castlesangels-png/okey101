import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:client_flutter/app/config.dart';

class GameApiService {
  GameApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');

  Future<Map<String, dynamic>> getGame(String gameId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/games/$gameId'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
    );

    final map = _decodeBodyToMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response.body, map, 'Oyun verisi alınamadı.'));
    }

    return map;
  }

  Future<Map<String, dynamic>> fetchGame(String gameId) async {
    return getGame(gameId);
  }

  Future<Map<String, dynamic>> getGameState(String gameId) async {
    return getGame(gameId);
  }

  Future<Map<String, dynamic>> startGame({
    Object? tableId,
    Object? token,
    Object? localUsername,
    Object? userId,
    Object? viewerUserId,
  }) async {
    final resolvedTableId = _text(tableId);
    if (resolvedTableId.isEmpty) {
      throw Exception('tableId boş olamaz.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_text(token).isNotEmpty) 'Authorization': 'Bearer ${_text(token)}',
    };

    final payload = <String, dynamic>{};
    final resolvedUserId = _text(userId);
    final resolvedViewerUserId = _text(viewerUserId);
    final resolvedLocalUsername = _text(localUsername);

    if (resolvedUserId.isNotEmpty) {
      payload['user_id'] = int.tryParse(resolvedUserId) ?? resolvedUserId;
      payload['userId'] = int.tryParse(resolvedUserId) ?? resolvedUserId;
    }

    if (resolvedViewerUserId.isNotEmpty) {
      payload['viewer_user_id'] = int.tryParse(resolvedViewerUserId) ?? resolvedViewerUserId;
      payload['viewerUserId'] = int.tryParse(resolvedViewerUserId) ?? resolvedViewerUserId;
    }

    if (resolvedLocalUsername.isNotEmpty) {
      payload['local_username'] = resolvedLocalUsername;
      payload['localUsername'] = resolvedLocalUsername;
    }

    final attempts = <Future<http.Response> Function()>[
      () => _client.post(
            Uri.parse('$_baseUrl/tables/$resolvedTableId/start-game'),
            headers: headers,
            body: jsonEncode(payload),
          ),
      () => _client.post(
            Uri.parse('$_baseUrl/tables/$resolvedTableId/start'),
            headers: headers,
            body: jsonEncode(payload),
          ),
      () => _client.post(
            Uri.parse('$_baseUrl/games/start'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'table_id': int.tryParse(resolvedTableId) ?? resolvedTableId,
              'tableId': int.tryParse(resolvedTableId) ?? resolvedTableId,
              ...payload,
            }),
          ),
      () => _client.get(
            Uri.parse('$_baseUrl/tables/$resolvedTableId/start-game'),
            headers: headers,
          ),
      () => _client.get(
            Uri.parse('$_baseUrl/tables/$resolvedTableId/start'),
            headers: headers,
          ),
    ];

    String lastError = 'Oyun başlatılamadı.';

    for (final attempt in attempts) {
      try {
        final response = await attempt();
        final map = _decodeBodyToMap(response.body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (map.isNotEmpty) {
            return map;
          }

          return <String, dynamic>{
            'id': resolvedTableId,
            'game_id': resolvedTableId,
            'table_id': resolvedTableId,
          };
        }

        lastError = _extractErrorMessage(response.body, map, lastError);

        if (!_isMethodOrRouteProblem(response.body, response.statusCode)) {
          throw Exception(lastError);
        }
      } catch (e) {
        lastError = e.toString().replaceFirst('Exception: ', '');
      }
    }

    throw Exception(lastError);
  }

  Future<Map<String, dynamic>> runBotTurns(String gameId) async {
    final attempts = <Future<http.Response> Function()>[
      () => _client.post(
            Uri.parse('$_baseUrl/games/$gameId/bot-turns'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{}),
          ),
      () => _client.post(
            Uri.parse('$_baseUrl/games/$gameId/bots/play'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{}),
          ),
    ];

    String lastError = 'Bot turları çalıştırılamadı.';

    for (final attempt in attempts) {
      try {
        final response = await attempt();
        final map = _decodeBodyToMap(response.body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return map;
        }

        lastError = _extractErrorMessage(response.body, map, lastError);

        if (!_isMethodOrRouteProblem(response.body, response.statusCode)) {
          throw Exception(lastError);
        }
      } catch (e) {
        lastError = e.toString().replaceFirst('Exception: ', '');
      }
    }

    throw Exception(lastError);
  }

  Future<Map<String, dynamic>> botTurns(String gameId) async {
    return runBotTurns(gameId);
  }

  Future<Map<String, dynamic>> playBotTurns(String gameId) async {
    return runBotTurns(gameId);
  }

  Map<String, dynamic> _decodeBodyToMap(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return <String, dynamic>{};
    }

    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return <String, dynamic>{'_raw': trimmed};
    }

    final decoded = jsonDecode(trimmed);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{'data': decoded};
  }

  String _extractErrorMessage(
    String body,
    Map<String, dynamic> map,
    String fallback,
  ) {
    final fromMap = map['message']?.toString() ??
        map['error']?.toString() ??
        map['_raw']?.toString();

    if (fromMap != null && fromMap.trim().isNotEmpty) {
      return fromMap.trim();
    }

    final trimmed = body.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return fallback;
  }

  bool _isMethodOrRouteProblem(String body, int statusCode) {
    final text = body.toLowerCase();
    return statusCode == 404 ||
        statusCode == 405 ||
        text.contains('method not allowed') ||
        text.contains('not found');
  }

  String _text(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
