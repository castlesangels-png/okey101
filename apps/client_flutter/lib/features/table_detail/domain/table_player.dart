class TablePlayer {
  final int userId;
  final String username;
  final String displayName;
  final int seatNo;

  TablePlayer({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.seatNo,
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

  factory TablePlayer.fromJson(Map<String, dynamic> json) {
    return TablePlayer(
      userId: _toInt(json['user_id']),
      username: _toStr(json['username']),
      displayName: _toStr(json['display_name']),
      seatNo: _toInt(json['seat_no']),
    );
  }
}
