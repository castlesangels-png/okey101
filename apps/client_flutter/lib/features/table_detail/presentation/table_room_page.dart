import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../app/config.dart';
import '../../game/data/game_api_service.dart';
import '../../game/presentation/game_table_page.dart';

class TableRoomPage extends StatefulWidget {
  TableRoomPage({
    super.key,
    required dynamic tableId,
    this.tableName,
    this.token,
    this.userId,
    this.viewerUserId,
    this.localUsername,
    this.onLogout,
  }) : tableId = tableId.toString();

  final String tableId;
  final String? tableName;
  final String? token;
  final dynamic userId;
  final dynamic viewerUserId;
  final String? localUsername;
  final VoidCallback? onLogout;

  @override
  State<TableRoomPage> createState() => _TableRoomPageState();
}

class _TableRoomPageState extends State<TableRoomPage> {
  final GameApiService _gameApi = GameApiService();
  final http.Client _client = http.Client();

  static const List<int> _botIds = <int>[1001, 1002, 1003, 1004];

  Timer? _pollTimer;
  Timer? _countdownTimer;

  bool _loading = true;
  bool _starting = false;
  bool _addingBot = false;
  bool _autoStartTriggered = false;

  String? _error;
  int? _countdown;

  Map<String, dynamic>? _table;
  List<Map<String, dynamic>> _players = <Map<String, dynamic>>[];

  String get _baseUrl => AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');

  @override
  void initState() {
    super.initState();
    _loadTable();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadTable(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _leaveTableSilently();
    _client.close();
    super.dispose();
  }

  Future<void> _leaveTableSilently() async {
    final userId = int.tryParse(widget.userId?.toString() ?? '') ?? 0;
    if (userId <= 0) {
      return;
    }

    try {
      await _client.post(
        Uri.parse('$_baseUrl/tables/${widget.tableId}/leave'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.trim().isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(<String, dynamic>{
          'user_id': userId,
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadTable({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/tables/${widget.tableId}'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.trim().isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
      );

      final body = response.body.trim();
      final decoded = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Masa bilgisi alınamadı.',
        );
      }

      final normalized = _unwrapData(decoded);
      final players = _extractPlayers(normalized);

      if (!mounted) {
        return;
      }

      setState(() {
        _table = normalized;
        _players = players;
        _loading = false;
        _error = null;
      });

      _handleAutoStart();
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

  Map<String, dynamic> _unwrapData(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return raw;
  }

  List<Map<String, dynamic>> _extractPlayers(Map<String, dynamic> raw) {
    final candidates = <dynamic>[
      raw['players'],
      raw['table_players'],
      raw['seats'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
            .toList();
      }
    }

    return <Map<String, dynamic>>[];
  }

  int get _maxPlayers {
    final value = _table?['max_players'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 4;
  }

  Future<void> _addBot() async {
    if (_addingBot) {
      return;
    }

    if (_players.length >= _maxPlayers) {
      setState(() {
        _error = 'Masa zaten dolu.';
      });
      return;
    }

    final usedIds = _players
        .map((p) => int.tryParse((p['user_id'] ?? '').toString()))
        .whereType<int>()
        .toSet();

    int? nextBotId;
    for (final id in _botIds) {
      if (!usedIds.contains(id)) {
        nextBotId = id;
        break;
      }
    }

    if (nextBotId == null) {
      setState(() {
        _error = 'Eklenebilecek bot kalmadı.';
      });
      return;
    }

    setState(() {
      _addingBot = true;
      _error = null;
    });

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/tables/${widget.tableId}/join'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (widget.token != null && widget.token!.trim().isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(<String, dynamic>{
          'user_id': nextBotId,
        }),
      );

      final body = response.body.trim();
      final decoded = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Bot eklenemedi.',
        );
      }

      await _loadTable(silent: true);
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
          _addingBot = false;
        });
      }
    }
  }

  void _handleAutoStart() {
    final playerCount = _players.length;

    if (playerCount >= _maxPlayers) {
      if (_autoStartTriggered) {
        return;
      }

      if (_countdownTimer == null) {
        setState(() {
          _countdown = 7;
        });

        _countdownTimer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) async {
            if (!mounted) {
              timer.cancel();
              return;
            }

            final current = _countdown ?? 0;
            if (current <= 1) {
              timer.cancel();
              _countdownTimer = null;
              setState(() {
                _countdown = 0;
              });
              await _startGame();
              return;
            }

            setState(() {
              _countdown = current - 1;
            });
          },
        );
      }
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      if (mounted) {
        setState(() {
          _countdown = null;
          _autoStartTriggered = false;
        });
      }
    }
  }

  Future<void> _startGame() async {
    if (_starting || _autoStartTriggered) {
      return;
    }

    setState(() {
      _starting = true;
      _autoStartTriggered = true;
      _error = null;
    });

    try {
      final result = await _gameApi.startGame(
        tableId: widget.tableId,
        userId: widget.userId,
        token: widget.token,
        viewerUserId: widget.viewerUserId,
        localUsername: widget.localUsername,
      );

      final data = result['data'] is Map<String, dynamic>
          ? result['data'] as Map<String, dynamic>
          : result;

      final gameId = (data['game_id'] ?? data['id'] ?? '').toString();
      if (gameId.isEmpty) {
        throw Exception('Oyun başlatıldı ama game id dönmedi.');
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameTablePage(
            gameId: gameId,
            tableId: widget.tableId,
            tableName: widget.tableName,
            token: widget.token,
            localUsername: widget.localUsername,
            userId: widget.userId,
            viewerUserId: widget.viewerUserId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _starting = false;
        _autoStartTriggered = false;
        _countdown = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.tableName?.trim().isNotEmpty ?? false)
        ? widget.tableName!.trim()
        : 'Başlangıç Masası';

    return Scaffold(
      backgroundColor: const Color(0xFF0B6A44),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    _TopHeader(
                      title: title,
                      playerCount: _players.length,
                      maxPlayers: _maxPlayers,
                      countdown: _countdown,
                      starting: _starting,
                      addingBot: _addingBot,
                      errorText: _error,
                      onBack: () => Navigator.of(context).maybePop(),
                      onAddBot: _addBot,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF125437),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF2E7D57),
                            width: 1.2,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final seats = List<Widget>.generate(4, (index) {
                              final player = index < _players.length
                                  ? _players[index]
                                  : null;
                              return _SeatCard(
                                seatNo: index + 1,
                                player: player,
                              );
                            });

                            final wide = constraints.maxWidth > 900;

                            if (wide) {
                              return Row(
                                children: <Widget>[
                                  Expanded(child: seats[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: seats[1]),
                                  const SizedBox(width: 12),
                                  Expanded(child: seats[2]),
                                  const SizedBox(width: 12),
                                  Expanded(child: seats[3]),
                                ],
                              );
                            }

                            return GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.3,
                              children: seats,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.playerCount,
    required this.maxPlayers,
    required this.countdown,
    required this.starting,
    required this.addingBot,
    required this.errorText,
    required this.onBack,
    required this.onAddBot,
  });

  final String title;
  final int playerCount;
  final int maxPlayers;
  final int? countdown;
  final bool starting;
  final bool addingBot;
  final String? errorText;
  final VoidCallback onBack;
  final VoidCallback onAddBot;

  @override
  Widget build(BuildContext context) {
    String statusText;
    if (starting) {
      statusText = 'Oyun başlatılıyor...';
    } else if (countdown != null) {
      statusText =
          '$maxPlayers kişi tamamlandı. Oyun $countdown saniye içinde başlayacak.';
    } else {
      statusText = 'Bot ekleyerek veya oyuncu bekleyerek masayı doldur.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF114F32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2E7D57),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Geri',
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: addingBot ? null : onAddBot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE0A800),
                  foregroundColor: Colors.black87,
                ),
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text(
                  'Bot Ekle',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Oyuncu: $playerCount / $maxPlayers',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (errorText != null && errorText!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFFFC107),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.seatNo,
    required this.player,
  });

  final int seatNo;
  final Map<String, dynamic>? player;

  @override
  Widget build(BuildContext context) {
    final occupied = player != null;
    final displayName = player?['display_name']?.toString() ??
        player?['name']?.toString() ??
        player?['username']?.toString() ??
        'Boş Koltuk';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: occupied ? const Color(0xFF1A7D53) : const Color(0xFF176445),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: occupied ? const Color(0xFF41B883) : const Color(0xFF2E7D57),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Koltuk $seatNo',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: occupied
                  ? const Color(0xFFE0A800)
                  : const Color(0x33FFFFFF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              occupied ? displayName.characters.first.toUpperCase() : '+',
              style: TextStyle(
                color: occupied ? Colors.black87 : Colors.white70,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
