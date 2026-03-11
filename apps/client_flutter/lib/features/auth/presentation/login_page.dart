import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/message_box.dart';

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
