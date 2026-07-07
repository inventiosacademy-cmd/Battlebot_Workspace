import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:my_flutter_app/core/constants/app_colors.dart';
import 'package:my_flutter_app/core/constants/app_sizes.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';

/// Login page with email/password authentication.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUpMode = false; // Mode toggle: false = Login, true = Register

  @override
  void initState() {
    super.initState();
    // Hilangkan status bar baterai, jam, dll. dan navigasi bawah untuk mode Fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSignUpMode && _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username tidak boleh kosong'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email dan password tidak boleh kosong'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    String? error;
    if (_isSignUpMode) {
      error = await auth.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _usernameController.text.trim(),
      );
    } else {
      error = await auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.dangerRed),
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.spacingXl,
          20, // Jarak atas logo dibuat sesedikit mungkin sesuai permintaan
          AppSizes.spacingXl,
          AppSizes.spacingXxxl,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 50, // Tinggi container dibuat lebih kecil
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/fontlogo.png',
                    height: 50, // Tinggi logo diset tepat 50px (terlihat jauh lebih kecil dan rapi)
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 25), // Jarak diset ke 25 (ditambah 15px dari sebelumnya 10px)
                if (_isSignUpMode) ...[
                  _UsernameField(controller: _usernameController),
                  const SizedBox(height: AppSizes.spacingXl),
                ],
                _EmailField(controller: _emailController),
                const SizedBox(height: AppSizes.spacingXl),
                _PasswordField(controller: _passwordController),
                const SizedBox(height: AppSizes.spacingXl), // Spasi lebih rapat
                _SubmitButton(
                  isLoading: _isLoading,
                  isSignUp: _isSignUpMode,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSizes.spacingLg),
                // Toggle antara Login dan Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUpMode ? 'Sudah punya akun? ' : 'Belum punya akun? ',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isSignUpMode = !_isSignUpMode),
                      child: Text(
                        _isSignUpMode ? 'Login di sini' : 'Daftar di sini',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacingXl),
                _GoogleSignInButton(
                  isLoading: _isLoading,
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final error = await auth.signInWithGoogle();
                    
                    if (error != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error), backgroundColor: AppColors.dangerRed),
                      );
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                ),
                const SizedBox(height: 16),
                _FacebookSignInButton(
                  isLoading: _isLoading,
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final error = await auth.signInWithFacebook();
                    
                    if (error != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error), backgroundColor: AppColors.dangerRed),
                      );
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  const _UsernameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _StyledTextField(
      controller: controller,
      label: 'Username',
      icon: Icons.person,
      isPassword: false,
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  const _EmailField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _StyledTextField(
      controller: controller,
      label: 'Email',
      icon: Icons.email,
      isPassword: false,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  const _PasswordField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _StyledTextField(
      controller: controller,
      label: 'Password',
      icon: Icons.lock,
      isPassword: true,
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.dangerRed,   // Merah
            AppColors.primaryBlue,  // Biru
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5), // Ketebalan outline gradasi merah-biru
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusXl - 1.5),
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.black54),
            prefixIcon: Icon(icon, color: AppColors.primaryBlue),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool isSignUp;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.isSignUp,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 42.0,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.dangerRed,   // Merah
            AppColors.primaryBlue,  // Biru
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                isSignUp ? 'REGISTER' : 'LOGIN',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42.0,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
        ),
        // Menggunakan logo Google asli yang telah diunduh
        icon: Image.asset(
          'assets/google_logo.png',
          height: 24,
        ),
        label: const Text(
          'SIGN IN WITH GOOGLE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _FacebookSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _FacebookSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42.0,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1877F2), width: 1.5),
          foregroundColor: const Color(0xFF1877F2),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
        ),
        icon: const Icon(Icons.facebook, size: 24, color: Color(0xFF1877F2)),
        label: const Text(
          'SIGN IN WITH FACEBOOK',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1877F2),
          ),
        ),
      ),
    );
  }
}
