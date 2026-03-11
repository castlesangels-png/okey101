import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/message_box.dart';

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
            MessageBox(message: errorText!, isError: true),
          ],
          if (successText != null) ...[
            const SizedBox(height: 16),
            MessageBox(message: successText!, isError: false),
          ],
        ],
      ),
    );
  }
}
