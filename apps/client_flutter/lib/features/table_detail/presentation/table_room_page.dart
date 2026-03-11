import 'package:flutter/material.dart';
import '../../game/data/game_api_service.dart';
import '../../game/presentation/game_table_page.dart';
import '../data/table_detail_api_service.dart';
import '../domain/table_detail.dart';
import '../domain/table_player.dart';
import 'widgets/player_seat_card.dart';
import 'widgets/table_center_board.dart';

class TableRoomPage extends StatefulWidget {
  final int tableId;
  final String tableName;
  final int viewerUserId;

  const TableRoomPage({
    super.key,
    required this.tableId,
    required this.tableName,
    required this.viewerUserId,
  });

  @override
  State<TableRoomPage> createState() => _TableRoomPageState();
}

class _TableRoomPageState extends State<TableRoomPage> {
  final TableDetailApiService _apiService = TableDetailApiService();
  final GameApiService _gameApiService = GameApiService();
  late Future<TableDetail> _detailFuture;
  bool _startingGame = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _apiService.fetchTableDetail(widget.tableId);
  }

  Future<void> _refresh() async {
    final future = _apiService.fetchTableDetail(widget.tableId);
    setState(() {
      _detailFuture = future;
    });
    await future;
  }

  TablePlayer? _seatPlayer(List<TablePlayer> players, int seatNo) {
    for (final player in players) {
      if (player.seatNo == seatNo) return player;
    }
    return null;
  }

  Widget _buildSeat({
    required int seatNo,
    required List<TablePlayer> players,
    required Axis rackDirection,
  }) {
    final player = _seatPlayer(players, seatNo);
    final occupied = player != null;
    final isYou = player?.userId == widget.viewerUserId;

    return PlayerSeatCard(
      seatNo: seatNo,
      title: occupied
          ? (player!.displayName.isNotEmpty ? player.displayName : player.username)
          : 'Bos koltuk',
      subtitle: occupied ? '@${player.username}' : 'Oyuncu bekleniyor',
      isOccupied: occupied,
      isYou: isYou,
      rackDirection: rackDirection,
    );
  }

  Future<void> _startGame() async {
    if (_startingGame) return;

    setState(() {
      _startingGame = true;
    });

    try {
      final result = await _gameApiService.startGame(
        tableId: widget.tableId,
        userId: widget.viewerUserId,
      );

      if (!mounted) return;

      final gameId = int.tryParse((result['game_id'] ?? '0').toString()) ?? 0;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameTablePage(
            gameId: gameId,
            tableId: widget.tableId,
            tableName: widget.tableName,
            viewerUserId: widget.viewerUserId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _startingGame = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tableName),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade50,
              Colors.grey.shade100,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<TableDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Masa detayi yuklenemedi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final detail = snapshot.data!;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Column(
                      children: [
                        _buildSeat(
                          seatNo: 1,
                          players: detail.players,
                          rackDirection: Axis.horizontal,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildSeat(
                                  seatNo: 4,
                                  players: detail.players,
                                  rackDirection: Axis.vertical,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Flexible(
                              flex: 2,
                              child: Center(
                                child: TableCenterBoard(
                                  tableName: detail.name,
                                  gameType: detail.gameType,
                                  currentPlayers: detail.currentPlayers,
                                  maxPlayers: detail.maxPlayers,
                                  minBuyIn: detail.minBuyIn,
                                  status: detail.status,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildSeat(
                                  seatNo: 2,
                                  players: detail.players,
                                  rackDirection: Axis.vertical,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSeat(
                          seatNo: 3,
                          players: detail.players,
                          rackDirection: Axis.horizontal,
                        ),
                        const SizedBox(height: 24),
                        if (_startingGame)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(),
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Masayi Yenile'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _startGame,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Oyunu Baslat'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
