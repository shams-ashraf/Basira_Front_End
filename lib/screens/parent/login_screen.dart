import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../l10n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = L10n.tr('login_fill_fields'));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final result = await AuthService.instance.login(email, password);
    if (!mounted) return;

    if (result.success) {
      final auth = await AuthService.instance.getAuth();
      if (!mounted) return;
      if (auth != null) {
        if (auth['role'] == 'parent') {
          Navigator.pushReplacementNamed(context, '/parent');
        } else {
          Navigator.pushReplacementNamed(context, '/child');
        }
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message ?? L10n.tr('login_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.remove_red_eye_rounded,
                size: 64,
                color: Color(0xFF17B890),
              ),
              const SizedBox(height: 16),
              Text(
                L10n.isArabic ? L10n.tr('login_welcome') : 'Welcome Back',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L10n.isArabic
                    ? L10n.tr('login_subtitle')
                    : 'Use your account to continue',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText:
                      L10n.isArabic ? L10n.tr('login_email') : 'Email Address',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.email_outlined, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF17B890), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText:
                      L10n.isArabic ? L10n.tr('login_password') : 'Password',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF17B890), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3D59),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          L10n.isArabic ? L10n.tr('login_button') : 'Login',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    L10n.isArabic
                        ? L10n.tr('login_no_account')
                        : 'Don’t have an account?',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: Text(
                      L10n.isArabic ? L10n.tr('login_signup_link') : 'Sign Up',
                      style: const TextStyle(
                        color: Color(0xFF17B890),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
