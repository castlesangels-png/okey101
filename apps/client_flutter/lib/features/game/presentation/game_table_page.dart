import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/data/game_api_service.dart';
import 'package:client_flutter/features/game/domain/game_state_mapper.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/discard_drop_zone_widget.dart';
import 'package:client_flutter/features/game/presentation/widgets/draw_pile_widget.dart';
import 'package:client_flutter/features/game/presentation/widgets/opponent_badge_widget.dart';
import 'package:client_flutter/features/game/presentation/widgets/player_rack_widget.dart';

class GameTablePage extends StatefulWidget {
  const GameTablePage({
    super.key,
    this.gameId,
    this.tableId,
    this.tableName,
    this.token,
    this.localUsername,
    this.userId,
    this.viewerUserId,
  });

  final Object? gameId;
  final Object? tableId;
  final Object? tableName;
  final Object? token;
  final Object? localUsername;
  final Object? userId;
  final Object? viewerUserId;

  String _asText(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String get resolvedGameId {
    final g = _asText(gameId);
    if (g.isNotEmpty) {
      return g;
    }
    return _asText(tableId);
  }

  String get resolvedTableName => _asText(tableName);
  String get resolvedViewerUserId => _asText(viewerUserId);

  @override
  State<GameTablePage> createState() => _GameTablePageState();
}

class _GameTablePageState extends State<GameTablePage> {
  final GameApiService _api = GameApiService();

  bool _loading = true;
  String? _error;

  ParsedGameState? _state;
  List<RackTileVm> _rackTiles = <RackTileVm>[];
  Set<int> _gapAfterIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    if (widget.resolvedGameId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Oyun kimliği bulunamadı.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _api.getGame(widget.resolvedGameId);
      final parsed = GameStateMapper.fromDynamic(
        raw,
        fallbackGameId: widget.resolvedGameId,
        fallbackViewerUserId: widget.resolvedViewerUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _state = parsed;
        _rackTiles = List<RackTileVm>.from(parsed.viewerHand);
        _gapAfterIndexes = <int>{};
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

  void _moveTile(int fromIndex, int toIndex) {
    if (fromIndex == toIndex || fromIndex < 0 || fromIndex >= _rackTiles.length) {
      return;
    }

    final updated = List<RackTileVm>.from(_rackTiles);
    final moved = updated.removeAt(fromIndex);

    var target = toIndex;
    if (toIndex > fromIndex) {
      target -= 1;
    }

    if (target < 0) {
      target = 0;
    }
    if (target > updated.length) {
      target = updated.length;
    }

    updated.insert(target, moved);

    setState(() {
      _rackTiles = updated;
      _gapAfterIndexes = <int>{};
    });
  }

  void _seriesArrange() {
    final arranged = RackArranger.arrangeSeries(_rackTiles);
    setState(() {
      _rackTiles = arranged.tiles;
      _gapAfterIndexes = arranged.gapAfterIndexes;
    });
  }

  void _pairsArrange() {
    final arranged = RackArranger.arrangePairs(_rackTiles);
    setState(() {
      _rackTiles = arranged.tiles;
      _gapAfterIndexes = arranged.gapAfterIndexes;
    });
  }

  void _discardFromRack(int fromIndex) {
    if (fromIndex < 0 || fromIndex >= _rackTiles.length) {
      return;
    }

    final updated = List<RackTileVm>.from(_rackTiles)..removeAt(fromIndex);

    setState(() {
      _rackTiles = updated;
      _gapAfterIndexes = <int>{};
    });
  }

  List<ParsedSeatVm> get _orderedSeats {
    final state = _state;
    if (state == null || state.seats.isEmpty) {
      return <ParsedSeatVm>[];
    }

    final myIndex = state.seats.indexWhere((e) => e.id == state.viewerSeatId);
    if (myIndex == -1) {
      return state.seats;
    }

    return <ParsedSeatVm>[
      ...state.seats.sublist(myIndex),
      ...state.seats.sublist(0, myIndex),
    ];
  }

  ParsedSeatVm? _seatAtOffset(int offset) {
    final seats = _orderedSeats;
    if (seats.length <= offset) {
      return null;
    }
    return seats[offset];
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.resolvedTableName.isNotEmpty
        ? widget.resolvedTableName
        : 'X 101 Salonu';

    return Scaffold(
      backgroundColor: const Color(0xFF0B5A43),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B5A43),
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _loadGame)
                : _buildStage(),
      ),
    );
  }

  Widget _buildStage() {
    final state = _state;
    if (state == null) {
      return _ErrorView(
        error: 'Oyun verisi boş geldi.',
        onRetry: _loadGame,
      );
    }

    final topSeat = _seatAtOffset(2);
    final leftSeat = _seatAtOffset(3);
    final rightSeat = _seatAtOffset(1);
    final mySeat = _seatAtOffset(0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: 1600,
              height: 900,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 350,
                    top: 80,
                    child: _MainSquareArea(
                      indicatorTile: state.indicatorTile,
                      drawPileCount: state.drawPileCount,
                    ),
                  ),

                  if (topSeat != null)
                    Positioned(
                      left: 640,
                      top: 12,
                      child: _SeatBadgeOnly(
                        seat: topSeat,
                        isActive: state.currentTurnSeatId == topSeat.id,
                      ),
                    ),

                  if (leftSeat != null)
                    Positioned(
                      left: 42,
                      top: 262,
                      child: _SeatBadgeOnly(
                        seat: leftSeat,
                        isActive: state.currentTurnSeatId == leftSeat.id,
                      ),
                    ),

                  if (rightSeat != null)
                    Positioned(
                      right: 42,
                      top: 262,
                      child: _SeatBadgeOnly(
                        seat: rightSeat,
                        isActive: state.currentTurnSeatId == rightSeat.id,
                      ),
                    ),

                  Positioned(
                    left: 1220,
                    top: 118,
                    child: _DiscardSlot(
                      tiles: topSeat?.discards ?? const <RackTileVm>[],
                    ),
                  ),

                  Positioned(
                    left: 215,
                    top: 330,
                    child: _DiscardSlot(
                      tiles: leftSeat?.discards ?? const <RackTileVm>[],
                    ),
                  ),

                  Positioned(
                    right: 215,
                    top: 330,
                    child: _DiscardSlot(
                      tiles: rightSeat?.discards ?? const <RackTileVm>[],
                    ),
                  ),

                  Positioned(
                    right: 122,
                    bottom: 120,
                    child: _DiscardSlot(
                      tiles: mySeat?.discards ?? const <RackTileVm>[],
                      onAcceptTile: _discardFromRack,
                    ),
                  ),

                  Positioned(
                    left: 70,
                    bottom: 30,
                    child: _BottomPlayerArea(
                      playerName: mySeat?.displayName ?? 'Sen',
                      currentTurn: state.currentTurnSeatId == mySeat?.id,
                      rackTiles: _rackTiles,
                      gapAfterIndexes: _gapAfterIndexes,
                      onMoveTile: _moveTile,
                      onSeriesArrange: _seriesArrange,
                      onPairsArrange: _pairsArrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MainSquareArea extends StatelessWidget {
  const _MainSquareArea({
    required this.indicatorTile,
    required this.drawPileCount,
  });

  final RackTileVm? indicatorTile;
  final int drawPileCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 900,
      height: 500,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                'X 101 Salonu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 112,
            child: Center(
              child: DrawPileWidget(
                indicatorTile: indicatorTile,
                drawCount: drawPileCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatBadgeOnly extends StatelessWidget {
  const _SeatBadgeOnly({
    required this.seat,
    required this.isActive,
  });

  final ParsedSeatVm seat;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return OpponentBadgeWidget(
      displayName: seat.displayName,
      username: seat.username,
      chips: seat.chips,
      modeText: 'Standart',
      isActiveTurn: isActive,
      avatarType: seat.avatarType,
    );
  }
}

class _DiscardSlot extends StatelessWidget {
  const _DiscardSlot({
    required this.tiles,
    this.onAcceptTile,
  });

  final List<RackTileVm> tiles;
  final void Function(int fromIndex)? onAcceptTile;

  @override
  Widget build(BuildContext context) {
    return DiscardDropZoneWidget(
      tiles: tiles,
      width: 78,
      height: 100,
      onAcceptTile: onAcceptTile,
      showFrame: true,
    );
  }
}

class _BottomPlayerArea extends StatelessWidget {
  const _BottomPlayerArea({
    required this.playerName,
    required this.currentTurn,
    required this.rackTiles,
    required this.gapAfterIndexes,
    required this.onMoveTile,
    required this.onSeriesArrange,
    required this.onPairsArrange,
  });

  final String playerName;
  final bool currentTurn;
  final List<RackTileVm> rackTiles;
  final Set<int> gapAfterIndexes;
  final void Function(int fromIndex, int toIndex) onMoveTile;
  final VoidCallback onSeriesArrange;
  final VoidCallback onPairsArrange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1420,
      height: 245,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0x14000000),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        playerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (currentTurn) ...<Widget>[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.radio_button_checked,
                          color: Color(0xFFFFC107),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: PlayerRackWidget(
                      tiles: rackTiles,
                      gapAfterIndexes: gapAfterIndexes,
                      onMoveTile: onMoveTile,
                      rackHeight: 168,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 104,
            child: Column(
              children: <Widget>[
                _SideActionButton(
                  title: 'Seri Diz',
                  onTap: onSeriesArrange,
                ),
                const SizedBox(height: 12),
                _SideActionButton(
                  title: 'Çift Diz',
                  onTap: onPairsArrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 96,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD8A94C),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 42, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
