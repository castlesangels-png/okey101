import 'package:flutter/material.dart';
import '../data/table_detail_api_service.dart';
import '../domain/table_detail.dart';

class TableRoomPage extends StatefulWidget {
  final int tableId;
  final String tableName;

  const TableRoomPage({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  @override
  State<TableRoomPage> createState() => _TableRoomPageState();
}

class _TableRoomPageState extends State<TableRoomPage> {
  final TableDetailApiService _apiService = TableDetailApiService();
  late Future<TableDetail> _detailFuture;

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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<TableDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.error_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Masa detayi yuklenemedi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final detail = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  detail.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Oyun: ${detail.gameType}'),
                Text('Oyuncu: ${detail.currentPlayers}/${detail.maxPlayers}'),
                Text('Min giris: ${detail.minBuyIn}'),
                Text('Durum: ${detail.status}'),
                const SizedBox(height: 24),
                const Text(
                  'Koltuklar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(4, (index) {
                  final seatNo = index + 1;
                  final player = detail.players.where((p) => p.seatNo == seatNo).cast().toList();

                  final seatPlayer = player.isNotEmpty ? player.first : null;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(seatNo.toString()),
                      ),
                      title: Text(
                        seatPlayer?.displayName.isNotEmpty == true
                            ? seatPlayer!.displayName
                            : 'Bos koltuk',
                      ),
                      subtitle: Text(
                        seatPlayer != null
                            ? '@${seatPlayer.username}'
                            : 'Oyuncu bekleniyor',
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
