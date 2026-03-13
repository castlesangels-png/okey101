import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../table_detail/presentation/table_room_page.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({
    super.key,
    this.token,
    this.userId,
    this.localUsername,
    this.displayName,
  });

  final String? token;
  final dynamic userId;
  final String? localUsername;
  final String? displayName;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final http.Client _client = http.Client();

  bool _loading = true;
  bool _creating = false;
  String? _error;

  List<Map<String, dynamic>> _tables = <Map<String, dynamic>>[];

  String get _baseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8080',
      ).replaceAll(RegExp(r'/$'), '');

  int get _currentUserId => int.tryParse(widget.userId?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/tables'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.trim().isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
      );

      final raw = response.body.trim();
      Map<String, dynamic> decoded;
      try {
        decoded = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = <String, dynamic>{
          'message': raw,
          'error': raw,
        };
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Masalar alınamadı.',
        );
      }

      final tablesRaw = decoded['tables'];
      final tables = tablesRaw is List
          ? tablesRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _tables = tables;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _createTable() async {
    if (_creating) {
      return;
    }

    if (_currentUserId <= 0) {
      setState(() {
        _error = 'Geçerli kullanıcı bulunamadı.';
      });
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final body = jsonEncode(<String, dynamic>{
        'user_id': _currentUserId,
        'name':
            '${widget.displayName ?? widget.localUsername ?? 'Oyuncu'} Masası',
        'game_type': '101',
        'max_players': 4,
        'min_buy_in': 0,
      });

      final response = await _client.post(
        Uri.parse('$_baseUrl/tables'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.trim().isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
        body: body,
      );

      final raw = response.body.trim();
      Map<String, dynamic> decoded;
      try {
        decoded = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = <String, dynamic>{
          'message': raw,
          'error': raw,
        };
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Masa oluşturulamadı.',
        );
      }

      final tableId = (decoded['table_id'] ?? '').toString();
      if (tableId.isEmpty) {
        throw Exception('Masa oluşturuldu ama table_id dönmedi.');
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => TableRoomPage(
                tableId: tableId,
                tableName:
                    '${widget.displayName ?? widget.localUsername ?? 'Oyuncu'} Masası',
                token: widget.token,
                userId: _currentUserId,
                viewerUserId: _currentUserId,
                localUsername: widget.localUsername,
              ),
            ),
          )
          .then((_) => _loadTables());
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _joinTable(Map<String, dynamic> table) async {
    if (_currentUserId <= 0) {
      setState(() {
        _error = 'Geçerli kullanıcı bulunamadı.';
      });
      return;
    }

    try {
      final tableId = table['id'].toString();

      final response = await _client.post(
        Uri.parse('$_baseUrl/tables/$tableId/join'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.trim().isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(<String, dynamic>{
          'user_id': _currentUserId,
        }),
      );

      final raw = response.body.trim();
      Map<String, dynamic> decoded;
      try {
        decoded = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = <String, dynamic>{
          'message': raw,
          'error': raw,
        };
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Masaya girilemedi.',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => TableRoomPage(
                tableId: tableId,
                tableName: table['name']?.toString(),
                token: widget.token,
                userId: _currentUserId,
                viewerUserId: _currentUserId,
                localUsername: widget.localUsername,
              ),
            ),
          )
          .then((_) => _loadTables());
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final welcome = widget.displayName ?? widget.localUsername ?? 'Oyuncu';

    return Scaffold(
      backgroundColor: const Color(0xFF0B6A44),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF114F32),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E7D57)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Merhaba, $welcome',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Masaları görüntüle, yeni masa oluştur veya mevcut masaya katıl.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_error != null &&
                            _error!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFFFC107),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _creating ? null : _createTable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0A800),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Masa Oluştur',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadTables,
                      child: _tables.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(24),
                              children: const <Widget>[
                                SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Açık masa yok.\nYeni masa oluşturarak başlayabilirsin.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: _tables.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final table = _tables[index];
                                final currentPlayers =
                                    table['current_players'] ?? 0;
                                final maxPlayers = table['max_players'] ?? 4;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF125437),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: const Color(0xFF2E7D57)),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE0A800),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${table['id']}',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              table['name']?.toString() ??
                                                  'Masa',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tür: ${table['game_type'] ?? '101'}  •  Oyuncu: $currentPlayers / $maxPlayers',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        onPressed: () => _joinTable(table),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1B7A53),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Masaya Gir',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
