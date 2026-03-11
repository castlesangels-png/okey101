import 'package:flutter/material.dart';
import '../data/game_api_service.dart';
import 'widgets/meld_area_widget.dart';
import 'widgets/player_rack_widget.dart';

class GameTablePage extends StatefulWidget {
  final int gameId;
  final int tableId;
  final String tableName;
  final int viewerUserId;

  const GameTablePage({
    super.key,
    required this.gameId,
    required this.tableId,
    required this.tableName,
    required this.viewerUserId,
  });

  @override
  State<GameTablePage> createState() => _GameTablePageState();
}

class _GameTablePageState extends State<GameTablePage> {
  final GameApiService _apiService = GameApiService();
  late Future<Map<String, dynamic>> _gameFuture;
  String? _selectedTileId;
  bool _busy = false;

  String _arrangeMode = 'default';
  int _groupedTotal = 0;
  List<Map<String, dynamic>>? _overrideHandForPreview;

  @override
  void initState() {
    super.initState();
    _gameFuture = _apiService.fetchGame(
      gameId: widget.gameId,
      viewerUserId: widget.viewerUserId,
    );
  }

  Future<void> _refresh() async {
    final future = _apiService.fetchGame(
      gameId: widget.gameId,
      viewerUserId: widget.viewerUserId,
    );
    setState(() {
      _gameFuture = future;
      _overrideHandForPreview = null;
      _arrangeMode = 'default';
      _groupedTotal = 0;
    });
    await future;
  }

  Future<void> _drawTile() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _apiService.drawTile(
        gameId: widget.gameId,
        userId: widget.viewerUserId,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardTileById(String tileId) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _apiService.discardTile(
        gameId: widget.gameId,
        userId: widget.viewerUserId,
        tileId: tileId,
      );
      _selectedTileId = null;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardSelected() async {
    if (_selectedTileId == null) return;
    await _discardTileById(_selectedTileId!);
  }

  Future<void> _openHand() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _apiService.openHand(
        gameId: widget.gameId,
        userId: widget.viewerUserId,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBotTurns() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _apiService.runBotTurns(gameId: widget.gameId);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _hiddenTiles(int count) {
    return List.generate(
      count,
      (_) => {'value': 'x', 'color': 'black'},
    );
  }

  List<Map<String, dynamic>> _toTileMaps(List<dynamic> raw) {
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return <String, dynamic>{
        'id': m['id']?.toString() ?? '',
        'value': (m['is_fake_okey'] == true)
            ? '*'
            : m['value']?.toString() ?? '',
        'numeric_value': m['value'] is int
            ? m['value']
            : int.tryParse(m['value']?.toString() ?? '') ?? 0,
        'color': m['color']?.toString() ?? 'black',
        'joker': m['is_okey'] == true,
        'fake_okey': m['is_fake_okey'] == true,
      };
    }).toList();
  }

  List<List<Map<String, dynamic>>> _toMeldMaps(List<dynamic> raw) {
    return raw.map((group) {
      final list = group as List<dynamic>;
      return _toTileMaps(list);
    }).toList();
  }

  Map<String, dynamic>? _seat(List<dynamic> seats, int seatNo) {
    for (final s in seats) {
      final m = Map<String, dynamic>.from(s as Map);
      if ((m['seat_no'] ?? 0) == seatNo) return m;
    }
    return null;
  }

  String _seatTitle(Map<String, dynamic>? seat, bool isViewer) {
    if (isViewer) return 'Sen';
    if (seat == null) return 'Bos Koltuk';
    return (seat['display_name'] ?? 'Oyuncu').toString();
  }

  int _colorOrder(String color) {
    switch (color) {
      case 'red':
        return 1;
      case 'blue':
        return 2;
      case 'black':
        return 3;
      case 'yellow':
        return 4;
      default:
        return 99;
    }
  }

  int _groupScore(List<Map<String, dynamic>> group) {
    return group.fold<int>(
      0,
      (sum, tile) => sum + ((tile['numeric_value'] ?? 0) as int),
    );
  }

  List<Map<String, dynamic>> _sortedLeftovers(List<Map<String, dynamic>> leftovers) {
    final copy = leftovers.map((e) => Map<String, dynamic>.from(e)).toList();
    copy.sort((a, b) {
      final colorCompare = _colorOrder(a['color'].toString()).compareTo(_colorOrder(b['color'].toString()));
      if (colorCompare != 0) return colorCompare;
      return (a['numeric_value'] as int).compareTo(b['numeric_value'] as int);
    });
    return copy;
  }

  List<List<Map<String, dynamic>>> _findRunCandidates(List<Map<String, dynamic>> tiles) {
    final groupedByColor = <String, List<Map<String, dynamic>>>{};

    for (final tile in tiles) {
      if (tile['joker'] == true || tile['fake_okey'] == true) continue;
      final color = tile['color'].toString();
      groupedByColor.putIfAbsent(color, () => []);
      groupedByColor[color]!.add(Map<String, dynamic>.from(tile));
    }

    final runs = <List<Map<String, dynamic>>>[];

    groupedByColor.forEach((color, list) {
      list.sort((a, b) => (a['numeric_value'] as int).compareTo(b['numeric_value'] as int));

      List<Map<String, dynamic>> current = [];

      for (int i = 0; i < list.length; i++) {
        final tile = list[i];

        if (current.isEmpty) {
          current.add(tile);
          continue;
        }

        final lastValue = current.last['numeric_value'] as int;
        final thisValue = tile['numeric_value'] as int;

        if (thisValue == lastValue + 1) {
          current.add(tile);
        } else if (thisValue == lastValue) {
          continue;
        } else {
          if (current.length >= 3) {
            runs.add(List<Map<String, dynamic>>.from(current));
          }
          current = [tile];
        }
      }

      if (current.length >= 3) {
        runs.add(List<Map<String, dynamic>>.from(current));
      }
    });

    return runs;
  }

  List<List<Map<String, dynamic>>> _findSetCandidates(List<Map<String, dynamic>> tiles) {
    final byValue = <int, List<Map<String, dynamic>>>{};

    for (final tile in tiles) {
      if (tile['joker'] == true || tile['fake_okey'] == true) continue;
      final value = (tile['numeric_value'] ?? 0) as int;
      byValue.putIfAbsent(value, () => []);
      byValue[value]!.add(Map<String, dynamic>.from(tile));
    }

    final sets = <List<Map<String, dynamic>>>[];

    byValue.forEach((value, list) {
      final byColor = <String, Map<String, dynamic>>{};
      for (final tile in list) {
        final color = tile['color'].toString();
        byColor.putIfAbsent(color, () => tile);
      }

      final unique = byColor.values.toList()
        ..sort((a, b) => _colorOrder(a['color'].toString()).compareTo(_colorOrder(b['color'].toString())));

      if (unique.length >= 3) {
        sets.add(unique.take(4).map((e) => Map<String, dynamic>.from(e)).toList());
      }
    });

    return sets;
  }

  bool _hasConflict(List<Map<String, dynamic>> group, Set<String> usedIds) {
    for (final tile in group) {
      final id = tile['id']?.toString() ?? '';
      if (id.isNotEmpty && usedIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _buildBestGrouping(List<Map<String, dynamic>> sourceTiles) {
    final tiles = sourceTiles
        .where((t) => t['gap'] != true)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final specialTiles = tiles.where((t) => t['joker'] == true || t['fake_okey'] == true).toList();
    final normals = tiles.where((t) => t['joker'] != true && t['fake_okey'] != true).toList();

    final runs = _findRunCandidates(normals);
    final sets = _findSetCandidates(normals);

    final candidates = <Map<String, dynamic>>[];

    for (final run in runs) {
      candidates.add({
        'tiles': run,
        'length': run.length,
        'score': _groupScore(run),
      });
    }

    for (final set in sets) {
      candidates.add({
        'tiles': set,
        'length': set.length,
        'score': _groupScore(set),
      });
    }

    candidates.sort((a, b) {
      final lenCompare = (b['length'] as int).compareTo(a['length'] as int);
      if (lenCompare != 0) return lenCompare;
      return (b['score'] as int).compareTo(a['score'] as int);
    });

    final usedIds = <String>{};
    final chosen = <List<Map<String, dynamic>>>[];

    for (final candidate in candidates) {
      final group = (candidate['tiles'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (_hasConflict(group, usedIds)) continue;

      chosen.add(group);
      for (final tile in group) {
        final id = tile['id']?.toString() ?? '';
        if (id.isNotEmpty) usedIds.add(id);
      }
    }

    final leftovers = <Map<String, dynamic>>[];
    for (final tile in normals) {
      final id = tile['id']?.toString() ?? '';
      if (!usedIds.contains(id)) {
        leftovers.add(Map<String, dynamic>.from(tile));
      }
    }

    final arranged = <Map<String, dynamic>>[];
    for (int i = 0; i < chosen.length; i++) {
      arranged.addAll(chosen[i]);
      if (i != chosen.length - 1) {
        arranged.add({'gap': true});
      }
    }

    if (chosen.isNotEmpty && (specialTiles.isNotEmpty || leftovers.isNotEmpty)) {
      arranged.add({'gap': true});
    }

    arranged.addAll(specialTiles.map((e) => Map<String, dynamic>.from(e)));
    arranged.addAll(_sortedLeftovers(leftovers));

    final total = chosen.fold<int>(
      0,
      (sum, group) => sum + _groupScore(group),
    );

    return {
      'arranged': arranged.isEmpty ? tiles : arranged,
      'total': total,
    };
  }

  void _applySeriesArrange(List<Map<String, dynamic>> sourceTiles) {
    final result = _buildBestGrouping(sourceTiles);

    setState(() {
      _arrangeMode = 'series';
      _groupedTotal = result['total'] as int;
      _overrideHandForPreview = (result['arranged'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });
  }

  void _applyPairArrange(List<Map<String, dynamic>> sourceTiles) {
    final tiles = sourceTiles
        .where((t) => t['gap'] != true)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final normalTiles = tiles.where((t) => t['joker'] != true && t['fake_okey'] != true).toList();
    final specialTiles = tiles.where((t) => t['joker'] == true || t['fake_okey'] == true).toList();

    final map = <String, List<Map<String, dynamic>>>{};
    for (final tile in normalTiles) {
      final key = '${tile['color']}-${tile['numeric_value']}';
      map.putIfAbsent(key, () => []);
      map[key]!.add(tile);
    }

    final pairGroups = <List<Map<String, dynamic>>>[];
    final leftovers = <Map<String, dynamic>>[];

    final keys = map.keys.toList()
      ..sort((a, b) {
        final aa = map[a]!.first;
        final bb = map[b]!.first;
        final lenCompare = map[b]!.length.compareTo(map[a]!.length);
        if (lenCompare != 0) return lenCompare;
        final colorCompare = _colorOrder(aa['color'].toString()).compareTo(_colorOrder(bb['color'].toString()));
        if (colorCompare != 0) return colorCompare;
        return (aa['numeric_value'] as int).compareTo(bb['numeric_value'] as int);
      });

    for (final key in keys) {
      final list = map[key]!;
      if (list.length >= 2) {
        pairGroups.add(list.map((e) => Map<String, dynamic>.from(e)).toList());
      } else {
        leftovers.addAll(list.map((e) => Map<String, dynamic>.from(e)));
      }
    }

    final arranged = <Map<String, dynamic>>[];
    for (int i = 0; i < pairGroups.length; i++) {
      arranged.addAll(pairGroups[i]);
      if (i != pairGroups.length - 1) {
        arranged.add({'gap': true});
      }
    }

    if (pairGroups.isNotEmpty && (specialTiles.isNotEmpty || leftovers.isNotEmpty)) {
      arranged.add({'gap': true});
    }

    arranged.addAll(specialTiles.map((e) => Map<String, dynamic>.from(e)));
    arranged.addAll(_sortedLeftovers(leftovers));

    setState(() {
      _arrangeMode = 'pairs';
      _groupedTotal = 0;
      _overrideHandForPreview = arranged.isEmpty ? tiles : arranged;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tableName} - Oyun'),
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
              Colors.green.shade100,
              Colors.green.shade50,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _gameFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(snapshot.error.toString()),
                ),
              );
            }

            final data = snapshot.data!;
            final seats = (data['seats'] as List?) ?? const [];
            final viewerSeatNo = (data['viewer_seat_no'] ?? 0) as int;
            final backendViewerHand = _toTileMaps((data['viewer_hand'] as List?) ?? const []);
            final viewerHand = _overrideHandForPreview ?? backendViewerHand;
            final centerMelds = _toMeldMaps((data['center_melds'] as List?) ?? const []);
            final discardPile = _toTileMaps((data['discard_pile'] as List?) ?? const []);
            final indicator = Map<String, dynamic>.from((data['indicator_tile'] as Map?) ?? const {});
            final okey = Map<String, dynamic>.from((data['okey_tile'] as Map?) ?? const {});
            final drawPileCount = (data['draw_pile_count'] ?? 0).toString();
            final currentTurnSeat = (data['current_turn_seat'] ?? 0) as int;
            final viewerLastDrawnTileID = (data['viewer_last_drawn_tile_id'] ?? '').toString();

            final topSeatNo = viewerSeatNo == 3 ? 1 : (viewerSeatNo == 1 ? 3 : 1);
            final leftSeatNo = viewerSeatNo == 1 ? 4 : (viewerSeatNo == 2 ? 1 : (viewerSeatNo == 3 ? 2 : 3));
            final rightSeatNo = viewerSeatNo == 1 ? 2 : (viewerSeatNo == 2 ? 3 : (viewerSeatNo == 3 ? 4 : 1));
            final bottomSeatNo = viewerSeatNo == 0 ? 3 : viewerSeatNo;

            final topSeat = _seat(seats, topSeatNo);
            final leftSeat = _seat(seats, leftSeatNo);
            final rightSeat = _seat(seats, rightSeatNo);
            final bottomSeat = _seat(seats, bottomSeatNo);

            final isMyTurn = currentTurnSeat == bottomSeatNo;
            final canDraw = isMyTurn && backendViewerHand.length == 21;
            final canDiscard = isMyTurn && backendViewerHand.length == 22 && _selectedTileId != null;
            final canOpen = isMyTurn && !_busy;

            final lastDiscard = discardPile.isEmpty ? null : discardPile.last;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlayerRackWidget(
                              title: _seatTitle(topSeat, false),
                              isActive: false,
                              isBottomPlayer: false,
                              tiles: _hiddenTiles((topSeat?['hand_count'] ?? 0) as int),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: PlayerRackWidget(
                                  title: _seatTitle(leftSeat, false),
                                  isActive: false,
                                  isBottomPlayer: false,
                                  tiles: _hiddenTiles((leftSeat?['hand_count'] ?? 0) as int),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  MeldAreaWidget(groups: centerMelds),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Wrap(
                                      spacing: 18,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        Text(
                                          'Masa ID: ${widget.tableId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text('Game ID: ${widget.gameId}'),
                                        Text('Sira: Koltuk $currentTurnSeat'),
                                        Text('Cekilecek tas: $drawPileCount'),
                                        Text('Gosterge: ${indicator['color'] ?? ''} ${indicator['value'] ?? ''}'),
                                        Text('Okey: ${okey['color'] ?? ''} ${okey['value'] ?? ''}'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DragTarget<String>(
                                    onWillAcceptWithDetails: (_) => canDiscard,
                                    onAcceptWithDetails: (details) async {
                                      await _discardTileById(details.data);
                                    },
                                    builder: (context, candidateData, rejectedData) {
                                      final active = candidateData.isNotEmpty;
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: active ? Colors.red.shade50 : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: active ? Colors.red.shade400 : Colors.grey.shade300,
                                            width: active ? 2 : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            const Text(
                                              'Tas Atma Alani',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              lastDiscard == null
                                                  ? 'Henüz atılan taş yok'
                                                  : 'Son tas: ${lastDiscard['color']} ${lastDiscard['value']}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              active
                                                  ? 'Buraya birakirsan tas atilir'
                                                  : 'Tasi surukleyip buraya birak',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  if (_arrangeMode == 'series')
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Text(
                                        'Toplam: $_groupedTotal',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: PlayerRackWidget(
                                  title: _seatTitle(rightSeat, false),
                                  isActive: false,
                                  isBottomPlayer: false,
                                  tiles: _hiddenTiles((rightSeat?['hand_count'] ?? 0) as int),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        PlayerRackWidget(
                          title: _seatTitle(bottomSeat, true),
                          isActive: isMyTurn,
                          isBottomPlayer: true,
                          tiles: viewerHand,
                          selectedTileId: _selectedTileId,
                          highlightedTileId: viewerLastDrawnTileID.isEmpty ? null : viewerLastDrawnTileID,
                          onTileTap: (tileId) {
                            setState(() {
                              _selectedTileId = _selectedTileId == tileId ? null : tileId;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMyTurn ? Colors.green.shade100 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMyTurn ? Colors.green.shade400 : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            isMyTurn
                                ? (backendViewerHand.length == 21
                                    ? 'Sira sende: once yerden tas cek'
                                    : 'Sira sende: bir tas sec ve at')
                                : 'Sira rakipte / botta',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: canDraw && !_busy ? _drawTile : null,
                              icon: const Icon(Icons.download),
                              label: const Text('Yerden Cek'),
                            ),
                            ElevatedButton.icon(
                              onPressed: canOpen ? _openHand : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('El Ac'),
                            ),
                            ElevatedButton.icon(
                              onPressed: !_busy ? () => _applySeriesArrange(backendViewerHand) : null,
                              icon: const Icon(Icons.linear_scale),
                              label: const Text('Seri Diz'),
                            ),
                            ElevatedButton.icon(
                              onPressed: !_busy ? () => _applyPairArrange(backendViewerHand) : null,
                              icon: const Icon(Icons.view_week),
                              label: const Text('Cift Diz'),
                            ),
                            ElevatedButton.icon(
                              onPressed: canDiscard && !_busy ? _discardSelected : null,
                              icon: const Icon(Icons.send),
                              label: const Text('Secili Tasi At'),
                            ),
                            OutlinedButton.icon(
                              onPressed: !_busy ? _runBotTurns : null,
                              icon: const Icon(Icons.smart_toy),
                              label: const Text('Botlar Oynasin'),
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
