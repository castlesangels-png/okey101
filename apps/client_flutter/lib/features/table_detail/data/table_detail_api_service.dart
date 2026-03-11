import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../app/config.dart';
import '../domain/table_detail.dart';

class TableDetailApiService {
  Future<TableDetail> fetchTableDetail(int tableId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/tables/$tableId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Masa detayi alinamadi: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return TableDetail.fromJson(decoded);
  }
}
