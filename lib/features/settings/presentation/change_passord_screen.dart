import 'package:faculty_pedia/core/services/api_service.dart';
import 'package:faculty_pedia/core/utils/snackbar_utils.dart';
import 'package:faculty_pedia/shared/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();

    // ✅ auto-fill email from logged-in user
    final user = ref.read(authStateProvider).user;
    if (user?.email != null) {
      _emailController.text = user!.email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String v) {
    final hasLower = RegExp(r'[a-z]').hasMatch(v);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    return v.length >= 8 && hasLower && hasUpper && hasDigit;
  }

  Future<void> _sendOtp() async {
    if (!_formKey1.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final api = ApiService();

      await api.post(
        "/api/auth/forgot-password",
        data: {
          "email": _emailController.text.trim(),
          "userType": "student".trim().toLowerCase(), // ✅ your logged-in user is student app
        },
      );

      if (!mounted) return;
      AppSnackbar.success(context, "OTP sent to your email");
      setState(() => _otpSent = true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey2.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final api = ApiService();

      await api.post(
        "/api/auth/reset-password",
        data: {
          "email": _emailController.text.trim(),
          "userType": "student",
          "otp": _otpController.text.trim(),
          "newPassword": _newPasswordController.text,
        },
      );

      if (!mounted) return;
      AppSnackbar.success(context, "Password changed successfully ✅");
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: !_otpSent ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Step 1: Request OTP",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),

          AppTextField(
            controller: _emailController,
            label: "Email Address",
            hint: "Enter registered email",
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              final v = value?.trim() ?? "";
              if (v.isEmpty) return "Email is required";
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return "Enter valid email";
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          AppButton(
            text: "Send OTP",
            isLoading: _loading,
            onPressed: _sendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Step 2: Verify OTP & Set New Password",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),

          // Email (readonly)
          AppTextField(
            controller: _emailController,
            label: "Email Address",
            hint: "Registered email",
            prefixIcon: const Icon(Icons.email_outlined),
            enabled: false,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _otpController,
            label: "OTP",
            hint: "Enter 6 digit OTP",
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.lock_outline),
            validator: (value) {
              final v = value?.trim() ?? "";
              if (v.isEmpty) return "OTP is required";
              if (!RegExp(r'^\d{6}$').hasMatch(v)) return "OTP must be 6 digits";
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _newPasswordController,
            label: "New Password",
            hint: "Min 8 chars (Aa1...)",
            obscureText: _obscureNew,
            prefixIcon: const Icon(Icons.password_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            validator: (value) {
              final v = value ?? "";
              if (v.isEmpty) return "New password is required";
              if (!_isStrongPassword(v)) {
                return "Password must contain lowercase, uppercase, number (min 8)";
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _confirmPasswordController,
            label: "Confirm Password",
            hint: "Re-enter password",
            obscureText: _obscureConfirm,
            prefixIcon: const Icon(Icons.password_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (value) {
              if ((value ?? "") != _newPasswordController.text) {
                return "Passwords do not match";
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          AppButton(
            text: "Change Password",
            isLoading: _loading,
            onPressed: _resetPassword,
          ),

          const SizedBox(height: 14),

          Center(
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () {
                setState(() {
                  _otpSent = false;
                  _otpController.clear();
                });
              },
              child: const Text("Resend OTP"),
            ),
          ),
        ],
      ),
    );
  }
}
