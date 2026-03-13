import 'dart:math';

enum RackTileColor {
  red,
  blue,
  yellow,
  black,
  unknown,
}

class RackTileVm {
  const RackTileVm({
    required this.id,
    required this.number,
    required this.color,
    this.isJoker = false,
  });

  final String id;
  final int number;
  final RackTileColor color;
  final bool isJoker;

  RackTileVm copyWith({
    String? id,
    int? number,
    RackTileColor? color,
    bool? isJoker,
  }) {
    return RackTileVm(
      id: id ?? this.id,
      number: number ?? this.number,
      color: color ?? this.color,
      isJoker: isJoker ?? this.isJoker,
    );
  }
}

class RackArrangeResult {
  const RackArrangeResult({
    required this.tiles,
    required this.gapAfterIndexes,
  });

  final List<RackTileVm> tiles;
  final Set<int> gapAfterIndexes;
}

class _TileRef {
  _TileRef(this.tile);

  final RackTileVm tile;
  bool used = false;
}

class RackArranger {
  static RackArrangeResult arrangeSeries(List<RackTileVm> source) {
    final refs = source.map(_TileRef.new).toList();
    final groups = <List<RackTileVm>>[];

    groups.addAll(_extractSameNumberGroups(refs, targetSize: 4));
    groups.addAll(_extractSameNumberGroups(refs, targetSize: 3));
    groups.addAll(_extractRuns(refs));

    final leftovers = refs
        .where((e) => !e.used)
        .map((e) => e.tile)
        .toList()
      ..sort(_defaultSortDesc);

    return _flatten(groups, leftovers);
  }

  static RackArrangeResult arrangePairs(List<RackTileVm> source) {
    final refs = source.map(_TileRef.new).toList();
    final groups = <List<RackTileVm>>[];

    final byNumber = <int, List<_TileRef>>{};
    for (final ref in refs.where((e) => !e.tile.isJoker)) {
      byNumber.putIfAbsent(ref.tile.number, () => <_TileRef>[]).add(ref);
    }

    final jokerRefs = refs.where((e) => e.tile.isJoker).toList();
    final numbers = byNumber.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final number in numbers) {
      final current = byNumber[number]!
        ..sort((a, b) => _defaultSortDesc(a.tile, b.tile));

      while (current.where((e) => !e.used).length >= 2) {
        final pair = current.where((e) => !e.used).take(2).toList();
        for (final ref in pair) {
          ref.used = true;
        }
        groups.add(pair.map((e) => e.tile).toList());
      }

      if (current.where((e) => !e.used).length == 1) {
        final joker = jokerRefs.cast<_TileRef?>().firstWhere(
              (e) => e != null && !e.used,
              orElse: () => null,
            );
        if (joker != null) {
          final single = current.firstWhere((e) => !e.used);
          single.used = true;
          joker.used = true;
          groups.add([single.tile, joker.tile]);
        }
      }
    }

    final leftovers = refs
        .where((e) => !e.used)
        .map((e) => e.tile)
        .toList()
      ..sort(_defaultSortDesc);

    return _flatten(groups, leftovers);
  }

  static RackArrangeResult _flatten(
    List<List<RackTileVm>> groups,
    List<RackTileVm> leftovers,
  ) {
    final flat = <RackTileVm>[];
    final gapAfterIndexes = <int>{};

    for (final group in groups) {
      if (group.isEmpty) {
        continue;
      }
      flat.addAll(group);
      gapAfterIndexes.add(flat.length - 1);
    }

    flat.addAll(leftovers);

    if (flat.isNotEmpty && gapAfterIndexes.contains(flat.length - 1)) {
      gapAfterIndexes.remove(flat.length - 1);
    }

    return RackArrangeResult(
      tiles: flat,
      gapAfterIndexes: gapAfterIndexes,
    );
  }

  static List<List<RackTileVm>> _extractSameNumberGroups(
    List<_TileRef> refs, {
    required int targetSize,
  }) {
    final groups = <List<RackTileVm>>[];
    final jokerRefs = refs.where((e) => !e.used && e.tile.isJoker).toList();

    final byNumber = <int, List<_TileRef>>{};
    for (final ref in refs.where((e) => !e.used && !e.tile.isJoker)) {
      byNumber.putIfAbsent(ref.tile.number, () => <_TileRef>[]).add(ref);
    }

    final numbers = byNumber.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final number in numbers) {
      final colorMap = <RackTileColor, _TileRef>{};

      for (final ref in byNumber[number]!) {
        if (ref.used) {
          continue;
        }
        colorMap.putIfAbsent(ref.tile.color, () => ref);
      }

      final chosen = colorMap.values.toList()
        ..sort((a, b) => _defaultSortDesc(a.tile, b.tile));

      final needed = targetSize - chosen.length;
      if (needed < 0) {
        chosen.removeRange(targetSize, chosen.length);
      }

      if (chosen.length < targetSize) {
        final availableJokers = jokerRefs.where((e) => !e.used).take(targetSize - chosen.length).toList();
        if (chosen.length + availableJokers.length < targetSize) {
          continue;
        }

        for (final ref in chosen) {
          ref.used = true;
        }
        for (final joker in availableJokers) {
          joker.used = true;
        }

        final group = <RackTileVm>[
          ...chosen.map((e) => e.tile),
          ...availableJokers.map((e) => e.tile),
        ];
        groups.add(group);
      } else {
        for (final ref in chosen.take(targetSize)) {
          ref.used = true;
        }
        groups.add(chosen.take(targetSize).map((e) => e.tile).toList());
      }
    }

    return groups;
  }

  static List<List<RackTileVm>> _extractRuns(List<_TileRef> refs) {
    final groups = <List<RackTileVm>>[];

    for (final color in RackTileColor.values) {
      if (color == RackTileColor.unknown) {
        continue;
      }

      while (true) {
        final normalRefs = refs
            .where((e) => !e.used && !e.tile.isJoker && e.tile.color == color)
            .toList()
          ..sort((a, b) => a.tile.number.compareTo(b.tile.number));

        final jokerRefs = refs.where((e) => !e.used && e.tile.isJoker).toList();

        if (normalRefs.length + jokerRefs.length < 3) {
          break;
        }

        final best = _findBestRun(normalRefs, jokerRefs);
        if (best == null || best.length < 3) {
          break;
        }

        for (final ref in best) {
          final original = refs.firstWhere((e) => identical(e, ref));
          original.used = true;
        }

        groups.add(best.map((e) => e.tile).toList());
      }
    }

    groups.sort((a, b) {
      final aMax = a.map((e) => e.number).fold<int>(0, max);
      final bMax = b.map((e) => e.number).fold<int>(0, max);
      if (aMax != bMax) {
        return bMax.compareTo(aMax);
      }
      return b.length.compareTo(a.length);
    });

    return groups;
  }

  static List<_TileRef>? _findBestRun(
    List<_TileRef> normalRefs,
    List<_TileRef> jokerRefs,
  ) {
    if (normalRefs.isEmpty && jokerRefs.length < 3) {
      return null;
    }

    final byNumber = <int, List<_TileRef>>{};
    for (final ref in normalRefs) {
      byNumber.putIfAbsent(ref.tile.number, () => <_TileRef>[]).add(ref);
    }

    List<_TileRef>? best;

    for (var start = 1; start <= 13; start++) {
      final usedLocal = <_TileRef>[];
      final usedJokers = <_TileRef>[];

      for (var value = start; value <= 13; value++) {
        final candidates = byNumber[value]?.where((e) => !usedLocal.contains(e)).toList() ?? <_TileRef>[];

        if (candidates.isNotEmpty) {
          usedLocal.add(candidates.first);
        } else {
          final joker = jokerRefs.where((e) => !usedJokers.contains(e)).cast<_TileRef?>().firstWhere(
                (e) => e != null,
                orElse: () => null,
              );
          if (joker == null) {
            break;
          }
          usedJokers.add(joker);
        }

        final current = <_TileRef>[...usedLocal, ...usedJokers];
        if (current.length >= 3) {
          if (best == null) {
            best = List<_TileRef>.from(current);
          } else {
            final bestNumbers = best.map((e) => e.tile.number).where((e) => e > 0).toList();
            final currentMax = value;
            final bestMax = bestNumbers.isEmpty ? 0 : bestNumbers.reduce(max);

            if (currentMax > bestMax || (currentMax == bestMax && current.length > best.length)) {
              best = List<_TileRef>.from(current);
            }
          }
        }
      }
    }

    if (best == null) {
      return null;
    }

    final orderedNormals = best.where((e) => !e.tile.isJoker).toList()
      ..sort((a, b) => a.tile.number.compareTo(b.tile.number));
    final orderedJokers = best.where((e) => e.tile.isJoker).toList();

    return [...orderedNormals, ...orderedJokers];
  }

  static int _defaultSortDesc(RackTileVm a, RackTileVm b) {
    if (a.isJoker != b.isJoker) {
      return a.isJoker ? 1 : -1;
    }
    if (a.number != b.number) {
      return b.number.compareTo(a.number);
    }
    return _colorOrder(a.color).compareTo(_colorOrder(b.color));
  }

  static int _colorOrder(RackTileColor color) {
    switch (color) {
      case RackTileColor.red:
        return 0;
      case RackTileColor.blue:
        return 1;
      case RackTileColor.black:
        return 2;
      case RackTileColor.yellow:
        return 3;
      case RackTileColor.unknown:
        return 4;
    }
  }
}
