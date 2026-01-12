import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _StudentSignupScreen();
  }
}

class _StudentSignupScreen extends ConsumerStatefulWidget {
  const _StudentSignupScreen();

  @override
  ConsumerState<_StudentSignupScreen> createState() =>
      _StudentSignupScreenState();
}

class _StudentSignupScreenState extends ConsumerState<_StudentSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedClass;
  String? _selectedSpecialization;

  File? _selectedImageFile;

  final _classes = const [
    'class-6th',
    'class-7th',
    'class-8th',
    'class-9th',
    'class-10th',
    'class-11th',
    'class-12th',
    'dropper',
  ];

  final _specializations = const ['IIT-JEE', 'NEET', 'CBSE'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
  String _usernameFromEmail(String email) {
    final cleaned = email.trim().toLowerCase();
    final atIndex = cleaned.indexOf('@');
    if (atIndex <= 0) return cleaned; // fallback
    return cleaned.substring(0, atIndex);
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      setState(() {
        _selectedImageFile = File(path);
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Failed to pick image');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
    });
  }

  bool _isStrongPassword(String v) {
    final hasLower = RegExp(r'[a-z]').hasMatch(v);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    return v.length >= 8 && hasLower && hasUpper && hasDigit;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClass == null) {
      AppSnackbar.warning(context, 'Please select your class');
      return;
    }
    if (_selectedSpecialization == null) {
      AppSnackbar.warning(context, 'Please select exam preparation');
      return;
    }
    final email = _emailController.text.trim();
    final username = _usernameFromEmail(email);
    final success = await ref.read(authStateProvider.notifier).signupStudent(
      name: _nameController.text.trim(),
      username: username,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      mobileNumber: _mobileController.text.trim(),
      specialization: _selectedSpecialization!,
      academicClass: _selectedClass!,
      imageFile: _selectedImageFile,
    );
    if (!success) return;
    if (success && mounted) {
      AppSnackbar.success(context, 'Account created successfully! Please login.');
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        AppSnackbar.error(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Student Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(60),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        backgroundImage:
                        _selectedImageFile != null ? FileImage(_selectedImageFile!) : null,
                        child: _selectedImageFile == null
                            ? Icon(
                          Icons.person,
                          size: 44,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )
                            : null,
                      ),
                    ),
                    if (_selectedImageFile != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: InkWell(
                          onTap: _removeImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              AppTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _mobileController,
                label: 'Mobile Number',
                hint: 'Enter your mobile number',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter your mobile number';
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                    return 'Enter valid 10-digit Indian number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text('Class', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedClass,
                decoration: const InputDecoration(
                  hintText: 'Select your class',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: _classes
                    .map(
                      (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.replaceAll('-', ' ').toUpperCase()),
                  ),
                )
                    .toList(),
                onChanged: (value) => setState(() => _selectedClass = value),
              ),
              const SizedBox(height: 16),

              Text('Exam Preparation',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedSpecialization,
                decoration: const InputDecoration(
                  hintText: 'Select exam',
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                items: _specializations
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedSpecialization = value),
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Min 8 chars (Aa1...)',
                obscureText: _obscurePassword,
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Please enter a password';
                  if (!_isStrongPassword(v)) {
                    return 'Password must contain lowercase, uppercase, number (min 8)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Re-enter password',
                obscureText: _obscureConfirmPassword,
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() =>
                  _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              AppButton(
                text: 'Create Student Account',
                isLoading: authState.isLoading,
                onPressed: _handleSignup,
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Login'),
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
