import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _otpLoadingProvider = StateProvider<bool>((ref) => false);
final _timerProvider = StateProvider<int>((ref) => 60);

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.mobile});

  final String mobile;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  String _otp = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_timerProvider.notifier).state = 60;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final current = ref.read(_timerProvider);
      if (current <= 0) {
        t.cancel();
      } else {
        ref.read(_timerProvider.notifier).state = current - 1;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      _showError('Please enter the 6-digit OTP');
      return;
    }
    ref.read(_otpLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.post('/api/auth/verify-otp', data: {
        'mobile': widget.mobile,
        'otp': _otp,
      });
      final data = resp.data as Map<String, dynamic>;
      const storage = FlutterSecureStorage();
      await storage.write(key: 'access_token', value: data['accessToken'] as String?);
      await storage.write(key: 'user_id', value: data['userId']?.toString());
      if (!mounted) return;
      context.go('/select-business');
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(e.response?.data?['message'] ?? 'Invalid OTP. Please try again.');
    } finally {
      if (mounted) ref.read(_otpLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _resendOtp() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/auth/send-otp', data: {'mobile': widget.mobile});
      ref.read(_timerProvider.notifier).state = 60;
      _startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP resent successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showError(e.response?.data?['message'] ?? 'Failed to resend OTP');
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
    final isLoading = ref.watch(_otpLoadingProvider);
    final remaining = ref.watch(_timerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.sms_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Verify OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit OTP sent to\n+91 ${widget.mobile}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10),
                  fieldHeight: 52,
                  fieldWidth: 44,
                  activeFillColor: Colors.white,
                  selectedFillColor: Colors.white,
                  inactiveFillColor: Colors.white,
                  activeColor: AppColors.primary,
                  selectedColor: AppColors.primary,
                  inactiveColor: AppColors.grey300,
                ),
                enableActiveFill: true,
                onChanged: (val) => _otp = val,
                onCompleted: (val) {
                  _otp = val;
                  _verifyOtp();
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Verify OTP',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (remaining > 0) ...[
                    const Text("Didn't receive OTP? ",
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text(
                      'Resend in ${remaining}s',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ] else ...[
                    const Text("Didn't receive OTP? ",
                        style: TextStyle(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: _resendOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Change Mobile Number',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
