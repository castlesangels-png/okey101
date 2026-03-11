import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

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
