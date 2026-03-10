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
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLoginMode = true;

  void toggleMode() {
    setState(() {
      isLoginMode = !isLoginMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoginMode
        ? LoginPage(onSwitchMode: toggleMode)
        : RegisterPage(onSwitchMode: toggleMode);
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onSwitchMode;

  const LoginPage({super.key, required this.onSwitchMode});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorText;
  Map<String, dynamic>? userData;

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8080/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifierController.text.trim(),
          'password': passwordController.text,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          userData = data['user'] as Map<String, dynamic>?;
        });
      } else {
        setState(() {
          errorText = data['message']?.toString() ?? 'Giriþ baþarýsýz';
          userData = null;
        });
      }
    } catch (e) {
      setState(() {
        errorText = 'Baðlantý hatasý: $e';
        userData = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
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
    final user = userData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Okey101 Giriþ'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: identifierController,
                  decoration: const InputDecoration(
                    labelText: 'Kullanýcý adý veya e-posta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Þifre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isLoading ? null : login,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Giriþ Yap'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onSwitchMode,
                  child: const Text('Hesabýn yok mu? Kayýt ol'),
                ),
                const SizedBox(height: 20),
                if (errorText != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (user != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giriþ baþarýlý',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('ID: ${user['id']}'),
                        Text('Kullanýcý adý: ${user['username']}'),
                        Text('E-posta: ${user['email']}'),
                        Text('Görünen ad: ${user['display_name']}'),
                        Text('Bakiye: ${user['balance']}'),
                        Text('Gold: ${user['is_gold']}'),
                        Text('Admin: ${user['is_admin']}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  final VoidCallback onSwitchMode;

  const RegisterPage({super.key, required this.onSwitchMode});

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
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8080/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'display_name': displayNameController.text.trim(),
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          successText = 'Kayýt baþarýlý. Þimdi giriþ yapabilirsin.';
        });
      } else {
        setState(() {
          errorText = data['message']?.toString() ?? 'Kayýt baþarýsýz';
        });
      }
    } catch (e) {
      setState(() {
        errorText = 'Baðlantý hatasý: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Okey101 Kayýt'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Kullanýcý adý',
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
                      labelText: 'Görünen ad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Þifre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: isLoading ? null : register,
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kayýt Ol'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onSwitchMode,
                    child: const Text('Zaten hesabýn var mý? Giriþ yap'),
                  ),
                  const SizedBox(height: 20),
                  if (errorText != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (successText != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        successText!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
