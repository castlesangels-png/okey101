import 'dart:convert';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';

class ParsedSeatVm {
  const ParsedSeatVm({
    required this.id,
    required this.displayName,
    required this.username,
    required this.chips,
    required this.avatarType,
    required this.isViewer,
    required this.discards,
    required this.handCount,
  });

  final String id;
  final String displayName;
  final String username;
  final int chips;
  final String? avatarType;
  final bool isViewer;
  final List<RackTileVm> discards;
  final int handCount;
}

class ParsedGameState {
  const ParsedGameState({
    required this.gameId,
    required this.viewerSeatId,
    required this.viewerHand,
    required this.seats,
    required this.melds,
    required this.indicatorTile,
    required this.drawPileCount,
    required this.currentTurnSeatId,
  });

  final String gameId;
  final String viewerSeatId;
  final List<RackTileVm> viewerHand;
  final List<ParsedSeatVm> seats;
  final List<List<RackTileVm>> melds;
  final RackTileVm? indicatorTile;
  final int drawPileCount;
  final String? currentTurnSeatId;
}

class GameStateMapper {
  static ParsedGameState fromDynamic(
    dynamic raw, {
    required String fallbackGameId,
    String? fallbackViewerUserId,
  }) {
    final root = _normalize(raw);
    final merged = _mergedRoot(root);

    final seatsRaw = _firstNonNull([
      merged['seats'],
      merged['players'],
      merged['table_players'],
      _deepFindByKey(merged, 'seats'),
      _deepFindByKey(merged, 'players'),
    ]);

    final seatMaps = seatsRaw is List
        ? seatsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final discardsMapRaw = _firstNonNull([
      merged['discards'],
      merged['discard_piles'],
      merged['discardPiles'],
      _deepFindByKey(merged, 'discards'),
      _deepFindByKey(merged, 'discard_piles'),
    ]);

    final discardsBySeat = discardsMapRaw is Map
        ? Map<String, dynamic>.from(discardsMapRaw)
        : <String, dynamic>{};

    final seats = seatMaps.map((seat) {
      final seatId = _stringOf(
        _firstNonNull([
          seat['id'],
          seat['seat_id'],
          seat['seatId'],
        ]),
      );

      final isViewer = _boolOf(
            _firstNonNull([
              seat['is_viewer'],
              seat['isViewer'],
              seat['is_me'],
              seat['isMe'],
            ]),
          ) ||
          (_stringOf(_firstNonNull([seat['user_id'], seat['userId']])) ==
              (fallbackViewerUserId ?? ''));

      return ParsedSeatVm(
        id: seatId,
        displayName: _stringOf(
          _firstNonNull([
            seat['display_name'],
            seat['displayName'],
            seat['name'],
            seat['player_name'],
            seat['playerName'],
            seat['username'],
            'Oyuncu',
          ]),
        ),
        username: _stringOf(
          _firstNonNull([
            seat['username'],
            seat['user_name'],
            seat['handle'],
            seat['display_name'],
            seat['name'],
            'oyuncu',
          ]),
        ),
        chips: _intOf(
          _firstNonNull([
            seat['chips'],
            seat['stack'],
            seat['balance'],
            seat['chip_count'],
          ]),
        ),
        avatarType: _nullableStringOf(
          _firstNonNull([
            seat['avatar_type'],
            seat['avatar'],
            seat['gender'],
          ]),
        ),
        isViewer: isViewer,
        discards: _parseTileList(
          _firstNonNull([
            seat['discards'],
            seat['discard_tiles'],
            seat['discardPile'],
            discardsBySeat[seatId],
          ]),
        ),
        handCount: _intOf(
          _firstNonNull([
            seat['hand_count'],
            seat['tile_count'],
            seat['tiles_count'],
          ]),
        ),
      );
    }).toList();

    String viewerSeatId = _stringOf(
      _firstNonNull([
        merged['viewer_seat_id'],
        merged['viewerSeatId'],
        merged['me_seat_id'],
        _deepFindByKey(merged, 'viewer_seat_id'),
        _deepFindByKey(merged, 'viewerSeatId'),
      ]),
    );

    if (viewerSeatId.isEmpty) {
      final viewerSeat = seats.cast<ParsedSeatVm?>().firstWhere(
            (e) => e != null && e.isViewer,
            orElse: () => null,
          );
      if (viewerSeat != null) {
        viewerSeatId = viewerSeat.id;
      }
    }

    final viewerContainers = <dynamic>[
      merged,
      merged['viewer'],
      merged['me'],
      merged['self'],
      merged['player'],
      merged['current_player'],
      merged['currentPlayer'],
      merged['player_state'],
      merged['viewer_state'],
      merged['game_state'],
      _deepFindByKey(merged, 'viewer'),
      _deepFindByKey(merged, 'me'),
      _deepFindByKey(merged, 'self'),
      _deepFindByKey(merged, 'player'),
      _deepFindByKey(merged, 'player_state'),
      _deepFindByKey(merged, 'viewer_state'),
    ];

    List<RackTileVm> viewerHand = <RackTileVm>[];

    for (final container in viewerContainers) {
      if (container == null) {
        continue;
      }

      final handCandidate = _firstNonNull([
        _extractFromContainer(container, 'viewer_hand'),
        _extractFromContainer(container, 'viewerHand'),
        _extractFromContainer(container, 'hand'),
        _extractFromContainer(container, 'player_hand'),
        _extractFromContainer(container, 'my_hand'),
        _extractFromContainer(container, 'myTiles'),
        _extractFromContainer(container, 'viewer_tiles'),
        _extractFromContainer(container, 'rack_tiles'),
        _extractFromContainer(container, 'rack'),
        _extractFromContainer(container, 'tiles'),
        _extractFromContainer(container, 'hand_tiles'),
      ]);

      viewerHand = _parseTileList(handCandidate);
      if (viewerHand.isNotEmpty) {
        break;
      }
    }

    if (viewerHand.isEmpty && viewerSeatId.isNotEmpty) {
      final viewerSeatMap = seatMaps.cast<Map<String, dynamic>?>().firstWhere(
            (e) =>
                e != null &&
                _stringOf(_firstNonNull([e['id'], e['seat_id'], e['seatId']])) == viewerSeatId,
            orElse: () => null,
          );

      if (viewerSeatMap != null) {
        viewerHand = _parseTileList(
          _firstNonNull([
            viewerSeatMap['hand'],
            viewerSeatMap['rack'],
            viewerSeatMap['tiles'],
            viewerSeatMap['viewer_hand'],
            viewerSeatMap['rack_tiles'],
            viewerSeatMap['hand_tiles'],
          ]),
        );
      }
    }

    final meldsRaw = _firstNonNull([
      merged['melds'],
      merged['table_melds'],
      merged['opened_sets'],
      _deepFindByKey(merged, 'melds'),
      _deepFindByKey(merged, 'table_melds'),
    ]);

    final melds = meldsRaw is List
        ? meldsRaw
            .whereType<List>()
            .map((e) => _parseTileList(e))
            .where((e) => e.isNotEmpty)
            .toList()
        : <List<RackTileVm>>[];

    return ParsedGameState(
      gameId: _stringOf(
        _firstNonNull([
          merged['game_id'],
          merged['id'],
          fallbackGameId,
        ]),
      ),
      viewerSeatId: viewerSeatId,
      viewerHand: viewerHand,
      seats: seats,
      melds: melds,
      indicatorTile: _parseSingleTile(
        _firstNonNull([
          merged['indicator_tile'],
          merged['indicatorTile'],
          merged['indicator'],
          _deepFindByKey(merged, 'indicator_tile'),
        ]),
      ),
      drawPileCount: _intOf(
        _firstNonNull([
          merged['draw_pile_count'],
          merged['drawPileCount'],
          merged['remaining_draw_pile_count'],
          merged['remainingCount'],
          _deepFindByKey(merged, 'draw_pile_count'),
          _deepFindByKey(merged, 'drawPileCount'),
        ]),
      ),
      currentTurnSeatId: _nullableStringOf(
        _firstNonNull([
          merged['current_turn_seat_id'],
          merged['currentTurnSeatId'],
          merged['turn_seat_id'],
          _deepFindByKey(merged, 'current_turn_seat_id'),
          _deepFindByKey(merged, 'currentTurnSeatId'),
        ]),
      ),
    );
  }

  static Map<String, dynamic> _mergedRoot(Map<String, dynamic> root) {
    final merged = <String, dynamic>{...root};

    for (final key in ['data', 'game', 'state', 'payload', 'result']) {
      final value = root[key];
      if (value is Map) {
        merged.addAll(Map<String, dynamic>.from(value));
      }
    }

    return merged;
  }

  static dynamic _extractFromContainer(dynamic container, String key) {
    if (container is Map) {
      if (container.containsKey(key)) {
        return container[key];
      }
      return _deepFindByKey(container, key);
    }
    return null;
  }

  static dynamic _deepFindByKey(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) {
        return node[key];
      }
      for (final value in node.values) {
        final found = _deepFindByKey(value, key);
        if (found != null) {
          return found;
        }
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _deepFindByKey(value, key);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  static dynamic _firstNonNull(List<dynamic> items) {
    for (final item in items) {
      if (item != null) {
        return item;
      }
    }
    return null;
  }

  static Map<String, dynamic> _normalize(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return <String, dynamic>{};
  }

  static List<RackTileVm> _parseTileList(dynamic raw) {
    if (raw is Map) {
      final nested = _firstNonNull([
        raw['tiles'],
        raw['hand'],
        raw['rack'],
        raw['viewer_hand'],
        raw['rack_tiles'],
        raw['hand_tiles'],
      ]);
      return _parseTileList(nested);
    }

    if (raw is! List) {
      return <RackTileVm>[];
    }

    final result = <RackTileVm>[];

    for (final item in raw) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        result.add(
          RackTileVm(
            id: _stringOf(
              _firstNonNull([
                map['id'],
                map['tile_id'],
                map['tileId'],
                '${_stringOf(map['color'])}_${_stringOf(map['number'] ?? map['value'])}_${map.hashCode}',
              ]),
            ),
            number: _intOf(_firstNonNull([map['number'], map['value'], map['rank']])),
            color: _mapColor(
              _stringOf(_firstNonNull([map['color'], map['tile_color'], map['suit']])),
            ),
            isJoker: _boolOf(_firstNonNull([map['is_joker'], map['joker'], map['isOkey']])),
          ),
        );
      } else if (item is String) {
        final parsed = _parseTileString(item);
        if (parsed != null) {
          result.add(parsed);
        }
      }
    }

    return result;
  }

  static RackTileVm? _parseSingleTile(dynamic raw) {
    final list = _parseTileList(raw is Map ? <dynamic>[raw] : raw);
    if (list.isEmpty) {
      return null;
    }
    return list.first;
  }

  static RackTileVm? _parseTileString(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }

    if (text.contains('joker') || text.contains('okey')) {
      return RackTileVm(
        id: raw,
        number: 0,
        color: RackTileColor.unknown,
        isJoker: true,
      );
    }

    final numberMatch = RegExp(r'(\d+)').firstMatch(text);
    final number = numberMatch != null ? int.tryParse(numberMatch.group(1)!) ?? 0 : 0;

    return RackTileVm(
      id: raw,
      number: number,
      color: _mapColor(text),
      isJoker: false,
    );
  }

  static RackTileColor _mapColor(String raw) {
    switch (raw.toLowerCase()) {
      case 'red':
      case 'kırmızı':
      case 'kirmizi':
        return RackTileColor.red;
      case 'blue':
      case 'mavi':
        return RackTileColor.blue;
      case 'yellow':
      case 'sarı':
      case 'sari':
        return RackTileColor.yellow;
      case 'black':
      case 'siyah':
        return RackTileColor.black;
      default:
        return RackTileColor.unknown;
    }
  }

  static String _stringOf(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  static String? _nullableStringOf(dynamic value) {
    final text = _stringOf(value).trim();
    return text.isEmpty ? null : text;
  }

  static int _intOf(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse(_stringOf(value)) ?? 0;
  }

  static bool _boolOf(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return _stringOf(value).toLowerCase() == 'true';
  }
}
