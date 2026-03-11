import 'package:flutter/material.dart';
import '../../table_detail/presentation/table_room_page.dart';
import '../data/lobby_api_service.dart';
import '../domain/game_table.dart';
import 'widgets/table_card.dart';

class LobbyPage extends StatefulWidget {
  final String displayName;
  final int userId;
  final VoidCallback? onLogout;

  const LobbyPage({
    super.key,
    required this.displayName,
    required this.userId,
    this.onLogout,
  });

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final LobbyApiService _lobbyApiService = LobbyApiService();
  late Future<List<GameTable>> _tablesFuture;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _tablesFuture = _lobbyApiService.fetchTables();
  }

  Future<void> _refreshTables() async {
    final future = _lobbyApiService.fetchTables();
    setState(() {
      _tablesFuture = future;
    });
    await future;
  }

  Future<void> _joinTable(GameTable table) async {
    if (_joining) return;
    if (widget.userId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gecersiz user id')),
      );
      return;
    }

    setState(() {
      _joining = true;
    });

    try {
      final result = await _lobbyApiService.joinTable(
        tableId: table.id,
        userId: widget.userId,
      );

      if (!mounted) return;

      final message = (result['message'] ?? 'Masaya katilindi').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      await _refreshTables();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TableRoomPage(
            tableId: table.id,
            tableName: table.name,
            viewerUserId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  void _logout() {
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        actions: [
          IconButton(
            onPressed: _refreshTables,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTables,
        child: FutureBuilder<List<GameTable>>(
          future: _tablesFuture,
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
                    'Masalar yuklenemedi',
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
                    onPressed: _refreshTables,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              );
            }

            final tables = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hos geldin, ${widget.displayName}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Aktif masalar'),
                const SizedBox(height: 16),
                if (_joining)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (tables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'Su anda masa bulunamadi',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                else
                  ...tables.map(
                    (table) => TableCard(
                      table: table,
                      onTap: () => _joinTable(table),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
