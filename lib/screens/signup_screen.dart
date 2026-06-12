import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = "parent";
  bool _isLoading = false;
  String _errorMessage = "";
  String _successMessage = "";

  static final RegExp _emailRegex = RegExp(
    r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
  );

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return "Email is required.";
    }
    if (!_emailRegex.hasMatch(email)) {
      return "Enter a valid email like name@example.com.";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return "Password is required.";
    }
    if (password.length < 8) {
      return "Use at least 8 characters.";
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return "Add at least one uppercase letter.";
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return "Add at least one lowercase letter.";
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return "Add at least one number.";
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\\/]').hasMatch(password)) {
      return "Add at least one special character.";
    }
    if (password.length > 72) {
      return "Keep it at 72 characters or fewer.";
    }
    return null;
  }

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _successMessage = "";
    });

    final result =
        await AuthService.instance.signup(email, password, _selectedRole);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isLoading = false;
        _successMessage =
            result.message ?? "Account created successfully! Please login.";
        _emailController.clear();
        _passwordController.clear();
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context); // Go back to login
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message ?? "Signup failed. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 64,
                  color: Color(0xFF17B890),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sign up as a parent or a child user",
                  style: TextStyle(
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
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                if (_successMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _successMessage,
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 13),
                    ),
                  ),
                TextFormField(
                  controller: _emailController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.email_outlined, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    helperText: "Use a valid email like name@example.com",
                    helperStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF17B890), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validatePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    helperText: "8+ chars, upper, lower, number, special char",
                    helperStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF17B890), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text("Parent Dashboard",
                          style: TextStyle(color: Colors.white)),
                      selected: _selectedRole == "parent",
                      selectedColor: const Color(0xFF1E3D59),
                      backgroundColor: const Color(0xFF1E1E1E),
                      onSelected: (val) {
                        if (val) setState(() => _selectedRole = "parent");
                      },
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text("Child Home",
                          style: TextStyle(color: Colors.white)),
                      selected: _selectedRole == "child",
                      selectedColor: const Color(0xFF17B890),
                      backgroundColor: const Color(0xFF1E1E1E),
                      onSelected: (val) {
                        if (val) setState(() => _selectedRole = "child");
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Password rules: 8+ chars, uppercase, lowercase, number, special character.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF17B890),
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
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
