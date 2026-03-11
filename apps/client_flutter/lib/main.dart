import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const Okey101App());
}

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
        scaffoldBackgroundColor: const Color(0xFFF4F6F1),
      ),
      home: const RootPage(),
    );
  }
}

class AppConfig {
  static const String baseUrl = 'http://127.0.0.1:8080';
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  Map<String, dynamic>? currentUser;

  void onLoggedIn(Map<String, dynamic> user) {
    setState(() {
      currentUser = user;
    });
  }

  void onLogout() {
    setState(() {
      currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return AuthPage(onLoggedIn: onLoggedIn);
    }

    return LobbyPage(
      user: currentUser!,
      onLogout: onLogout,
    );
  }
}

class ApiService {
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message']?.toString() ?? 'Giris basarisiz');
    }

    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'display_name': displayName.trim(),
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message']?.toString() ?? 'Kayit basarisiz');
    }

    return data;
  }
}

class AuthPage extends StatefulWidget {
  final void Function(Map<String, dynamic> user) onLoggedIn;

  const AuthPage({super.key, required this.onLoggedIn});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLoginMode = true;

  void switchToLogin() {
    setState(() {
      isLoginMode = true;
    });
  }

  void switchToRegister() {
    setState(() {
      isLoginMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoginMode
        ? LoginPage(
            onSwitchMode: switchToRegister,
            onLoggedIn: widget.onLoggedIn,
          )
        : RegisterPage(
            onSwitchMode: switchToLogin,
          );
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onSwitchMode;
  final void Function(Map<String, dynamic> user) onLoggedIn;

  const LoginPage({
    super.key,
    required this.onSwitchMode,
    required this.onLoggedIn,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final data = await ApiService.login(
        identifier: identifierController.text,
        password: passwordController.text,
      );

      final user = data['user'] as Map<String, dynamic>?;
      if (user == null) {
        throw Exception('Kullanici verisi gelmedi');
      }

      widget.onLoggedIn(user);
    } catch (e) {
      setState(() {
        errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Okey101 Giris',
      subtitle: 'Hesabina gir ve lobbye gec',
      child: Column(
        children: [
          TextField(
            controller: identifierController,
            decoration: const InputDecoration(
              labelText: 'Kullanici adi veya e-posta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Sifre',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => isLoading ? null : login(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: isLoading ? null : login,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Giris Yap'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onSwitchMode,
            child: const Text('Hesabin yok mu? Kayit ol'),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 16),
            MessageBox(
              message: errorText!,
              isError: true,
            ),
          ],
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  final VoidCallback onSwitchMode;

  const RegisterPage({
    super.key,
    required this.onSwitchMode,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final displayNameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorText;
  String? successText;

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      errorText = null;
      successText = null;
    });

    try {
      await ApiService.register(
        username: usernameController.text,
        email: emailController.text,
        password: passwordController.text,
        displayName: displayNameController.text,
      );

      setState(() {
        successText = 'Kayit basarili. Simdi giris yapabilirsin.';
      });
    } catch (e) {
      setState(() {
        errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    displayNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Okey101 Kayit',
      subtitle: 'Yeni hesap olustur',
      child: Column(
        children: [
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Kullanici adi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: displayNameController,
            decoration: const InputDecoration(
              labelText: 'Gorunen ad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Sifre',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => isLoading ? null : register(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: isLoading ? null : register,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kayit Ol'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onSwitchMode,
            child: const Text('Zaten hesabin var mi? Giris yap'),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 16),
            MessageBox(
              message: errorText!,
              isError: true,
            ),
          ],
          if (successText != null) ...[
            const SizedBox(height: 16),
            MessageBox(
              message: successText!,
              isError: false,
            ),
          ],
        ],
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 28),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LobbyPage extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  const LobbyPage({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = user['display_name']?.toString() ?? '-';
    final username = user['username']?.toString() ?? '-';
    final email = user['email']?.toString() ?? '-';
    final balance = user['balance']?.toString() ?? '0';
    final isGold = user['is_gold'] == true;
    final isAdmin = user['is_admin'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Okey101 Lobby'),
        actions: [
          TextButton(
            onPressed: onLogout,
            child: const Text('Cikis Yap'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                UserSummaryCard(
                  displayName: displayName,
                  username: username,
                  email: email,
                  balance: balance,
                  isGold: isGold,
                  isAdmin: isAdmin,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LobbyModeCard(
                                    title: 'Tekli Oyun',
                                    subtitle:
                                        'Bireysel masa sistemi icin giris noktasi',
                                    icon: Icons.person,
                                    buttonText: 'Tekli Modu Sec',
                                    onPressed: () {
                                      _showPlaceholder(context, 'Tekli mod');
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: LobbyModeCard(
                                    title: 'Esli Oyun',
                                    subtitle:
                                        'Takimli / esli masa sistemi icin giris noktasi',
                                    icon: Icons.groups,
                                    buttonText: 'Esli Modu Sec',
                                    onPressed: () {
                                      _showPlaceholder(context, 'Esli mod');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Masa Listesi',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: () {
                                              _showPlaceholder(
                                                context,
                                                'Masa olusturma',
                                              );
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('Masa Olustur'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: ListView(
                                          children: const [
                                            TablePlaceholderTile(
                                              title: 'Dusuk Bahis Masa',
                                              subtitle:
                                                  '4 kisilik • Tekli • Bekliyor',
                                              trailing: '1000 cip',
                                            ),
                                            TablePlaceholderTile(
                                              title: 'Orta Bahis Masa',
                                              subtitle:
                                                  '4 kisilik • Esli • Bekliyor',
                                              trailing: '5000 cip',
                                            ),
                                            TablePlaceholderTile(
                                              title: 'Yuksek Bahis Masa',
                                              subtitle:
                                                  '4 kisilik • Tekli • Bekliyor',
                                              trailing: '10000 cip',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            const QuickInfoCard(
                              title: 'Duyurular',
                              content:
                                  'Yonetim panelinden baglanacak duyurular burada gosterilecek.',
                            ),
                            const SizedBox(height: 16),
                            const QuickInfoCard(
                              title: 'Gunluk Gorevler',
                              content:
                                  'Gunluk bonus, gorev ve odul sistemi burada yer alacak.',
                            ),
                            const SizedBox(height: 16),
                            const QuickInfoCard(
                              title: 'Yakinda',
                              content:
                                  'Arkadas sistemi, ozel mesajlar, market ve gold uyelik eklenecek.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showPlaceholder(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName alani henuz placeholder durumda.'),
      ),
    );
  }
}

class UserSummaryCard extends StatelessWidget {
  final String displayName;
  final String username;
  final String email;
  final String balance;
  final bool isGold;
  final bool isAdmin;

  const UserSummaryCard({
    super.key,
    required this.displayName,
    required this.username,
    required this.email,
    required this.balance,
    required this.isGold,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.green.shade100,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                runSpacing: 8,
                spacing: 16,
                children: [
                  _InfoChip(label: 'Ad', value: displayName),
                  _InfoChip(label: 'Username', value: username),
                  _InfoChip(label: 'E-posta', value: email),
                  _InfoChip(label: 'Bakiye', value: balance),
                  _InfoChip(label: 'Gold', value: isGold ? 'Evet' : 'Hayir'),
                  _InfoChip(label: 'Admin', value: isAdmin ? 'Evet' : 'Hayir'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class LobbyModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String buttonText;
  final VoidCallback onPressed;

  const LobbyModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickInfoCard extends StatelessWidget {
  final String title;
  final String content;

  const QuickInfoCard({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(content),
          ],
        ),
      ),
    );
  }
}

class TablePlaceholderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const TablePlaceholderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gercek masa baglantisi daha sonra eklenecek.'),
              ),
            );
          },
          child: Text(trailing),
        ),
      ),
    );
  }
}

class MessageBox extends StatelessWidget {
  final String message;
  final bool isError;

  const MessageBox({
    super.key,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isError ? Colors.red.withOpacity(0.10) : Colors.green.withOpacity(0.10);
    final textColor = isError ? Colors.red : Colors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(color: textColor),
      ),
    );
  }
}