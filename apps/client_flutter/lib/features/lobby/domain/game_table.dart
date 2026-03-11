class GameTable {
  final int id;
  final String name;
  final String gameType;
  final int maxPlayers;
  final int currentPlayers;
  final int minBuyIn;
  final String status;

  GameTable({
    required this.id,
    required this.name,
    required this.gameType,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.minBuyIn,
    required this.status,
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _toStr(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory GameTable.fromJson(Map<String, dynamic> json) {
    return GameTable(
      id: _toInt(json['id']),
      name: _toStr(json['name']),
      gameType: _toStr(json['game_type']),
      maxPlayers: _toInt(json['max_players']),
      currentPlayers: _toInt(json['current_players']),
      minBuyIn: _toInt(json['min_buy_in']),
      status: _toStr(json['status']),
    );
  }
}
