import 'package:flutter/material.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/lobby/presentation/lobby_page.dart';

class Okey101App extends StatelessWidget {
  const Okey101App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Okey101',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Map<String, dynamic>? _currentUser;

  void _handleLoggedIn(Map<String, dynamic> user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _handleLogout() {
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return AuthPage(
        onLoggedIn: _handleLoggedIn,
      );
    }

    final displayName = (_currentUser!['display_name'] ??
            _currentUser!['displayName'] ??
            _currentUser!['username'] ??
            'Oyuncu')
        .toString();

    final userId = int.tryParse(
          (_currentUser!['id'] ?? _currentUser!['user_id'] ?? '0').toString(),
        ) ??
        0;

    return LobbyPage(
      displayName: displayName,
      userId: userId,
    );
  }
}
