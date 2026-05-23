import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _loginLoadingProvider = StateProvider<bool>((ref) => false);
final _activeTabProvider = StateProvider<int>((ref) => 0);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKeyMobile = GlobalKey<FormState>();
  final _formKeyEmail = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      ref.read(_activeTabProvider.notifier).state = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKeyMobile.currentState!.validate()) return;
    ref.read(_loginLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/auth/send-otp', data: {
        'mobile': _mobileController.text.trim(),
      });
      if (!mounted) return;
      context.push('/otp', extra: _mobileController.text.trim());
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(e.response?.data?['message'] ?? 'Failed to send OTP');
    } finally {
      if (mounted) ref.read(_loginLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _emailLogin() async {
    if (!_formKeyEmail.currentState!.validate()) return;
    ref.read(_loginLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/auth/login', data: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      if (!mounted) return;
      context.go('/select-business');
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(e.response?.data?['message'] ?? 'Invalid credentials');
    } finally {
      if (mounted) ref.read(_loginLoadingProvider.notifier).state = false;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_loginLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 56),
              const Icon(Icons.account_balance,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'VYAPAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'GST Accounting for your business',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Mobile OTP'),
                        Tab(text: 'Email'),
                      ],
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: 220,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _MobileOtpForm(
                              formKey: _formKeyMobile,
                              controller: _mobileController,
                              isLoading: isLoading,
                              onSendOtp: _sendOtp,
                            ),
                            _EmailLoginForm(
                              formKey: _formKeyEmail,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              onTogglePassword: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                              isLoading: isLoading,
                              onLogin: _emailLogin,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => context.push('/create-business'),
                    child: const Text(
                      'Register',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileOtpForm extends StatelessWidget {
  const _MobileOtpForm({
    required this.formKey,
    required this.controller,
    required this.isLoading,
    required this.onSendOtp,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSendOtp;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              hintText: '10-digit mobile number',
              prefixText: '+91  ',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter mobile number';
              if (v.length != 10) return 'Enter valid 10-digit number';
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Send OTP',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailLoginForm extends StatelessWidget {
  const _EmailLoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.isLoading,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final bool isLoading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter email';
              if (!v.contains('@')) return 'Enter valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: onTogglePassword,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter password';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Login',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
