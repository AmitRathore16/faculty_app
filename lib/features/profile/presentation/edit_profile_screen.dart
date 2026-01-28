import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:faculty_pedia/core/services/api_service.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';

/// ✅ Student profile provider (dynamic from backend)
final editStudentProfileProvider =
FutureProvider.autoDispose<Student>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.user;

  if (user == null) throw Exception("Please login");

  final api = ApiService();
  final res = await api.get('/api/students/${user.id}');

  dynamic data = res.data;
  if (data is Map && data['data'] != null) data = data['data'];

  return Student.fromJson(Map<String, dynamic>.from(data));
});

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  String? _selectedClass; // must be slug: class-10th etc
  String? _selectedSpecialization;

  File? _selectedImageFile;

  bool _isSaving = false;
  bool _didPrefill = false;

  /// ✅ Only slug values must be sent to backend
  final _classOptions = const [
    {'label': 'Class 6th', 'value': 'class-6th'},
    {'label': 'Class 7th', 'value': 'class-7th'},
    {'label': 'Class 8th', 'value': 'class-8th'},
    {'label': 'Class 9th', 'value': 'class-9th'},
    {'label': 'Class 10th', 'value': 'class-10th'},
    {'label': 'Class 11th', 'value': 'class-11th'},
    {'label': 'Class 12th', 'value': 'class-12th'},
    {'label': 'Dropper', 'value': 'dropper'},
  ];

  final _specializations = const ['IIT-JEE', 'NEET', 'CBSE'];

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  /// ✅ Backend expects slug values (class-10th) but sometimes profile returns "Class 10th"
  String? _normalizeClassToSlug(String? v) {
    if (v == null || v.trim().isEmpty) return null;

    final trimmed = v.trim();

    // already slug
    if (trimmed.startsWith("class-") || trimmed == "dropper") return trimmed;

    const map = {
      "Class 6th": "class-6th",
      "Class 7th": "class-7th",
      "Class 8th": "class-8th",
      "Class 9th": "class-9th",
      "Class 10th": "class-10th",
      "Class 11th": "class-11th",
      "Class 12th": "class-12th",
      "Dropper": "dropper",
    };

    return map[trimmed] ?? trimmed;
  }

  void _prefill(Student s) {
    if (_didPrefill) return;
    _didPrefill = true;

    _nameController.text = s.name ?? s.displayName;
    _mobileController.text = s.mobileNumber ?? '';
    _selectedSpecialization = s.specialization;

    /// ✅ FIX: convert "Class 10th" -> "class-10th"
    _selectedClass = _normalizeClassToSlug(s.academicClass);
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

      setState(() => _selectedImageFile = File(path));
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, "Failed to pick image");
    }
  }

  void _removeImage() => setState(() => _selectedImageFile = null);

  /// ✅ EXACT LIKE SIGNUP IMAGE UPLOAD
  Future<String?> _uploadImage(ApiService api) async {
    if (_selectedImageFile == null) return null;

    try {
      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          _selectedImageFile!.path,
          filename: _selectedImageFile!.path.split('/').last,
        ),
      });

      final res = await api.post(
        "/api/upload/image",
        data: formData,
      );

      final data = res.data;

      // backend returns: { success, imageUrl, publicId }
      if (data is Map && data["imageUrl"] != null) {
        return data["imageUrl"].toString();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile(Student student) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClass == null) {
      AppSnackbar.warning(context, 'Please select your class');
      return;
    }

    if (_selectedSpecialization == null) {
      AppSnackbar.warning(context, 'Please select exam preparation');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ApiService();

      // ✅ upload image first (if picked)
      final uploadedImageUrl = await _uploadImage(api);

      /// ✅ IMPORTANT:
      /// backend expects:
      /// class: class-10th, specialization: IIT-JEE, mobileNumber, name, image
      final payload = <String, dynamic>{
        "name": _nameController.text.trim(),
        "mobileNumber": _mobileController.text.trim(),
        "specialization": _selectedSpecialization,
        "class": _selectedClass, // ✅ MUST BE SLUG
        if (uploadedImageUrl != null) "image": uploadedImageUrl,
      };

      await api.put("/api/students/${student.id}", data: payload);

      if (!mounted) return;
      AppSnackbar.success(context, "Profile updated successfully");
      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      // show proper dio message if available
      if (e is DioException) {
        final msg = e.response?.data?['message']?.toString() ?? e.message;
        AppSnackbar.error(context, msg ?? "Update failed");
      } else {
        AppSnackbar.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(editStudentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Edit Profile"),
      ),
      body: studentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Failed: $e")),
        data: (student) {
          _prefill(student);

          return SingleChildScrollView(
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
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            backgroundImage: _selectedImageFile != null
                                ? FileImage(_selectedImageFile!)
                                : (student.imageUrl != null &&
                                student.imageUrl!.isNotEmpty)
                                ? NetworkImage(student.imageUrl!)
                            as ImageProvider
                                : null,
                            child: (_selectedImageFile == null &&
                                (student.imageUrl == null ||
                                    student.imageUrl!.isEmpty))
                                ? Icon(
                              Icons.person,
                              size: 44,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

                  /// ✅ Email show only (readonly)
                  AppTextField(
                    controller: TextEditingController(text: student.email),
                    label: 'Email Address',
                    hint: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    enabled: false,
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
                    items: _classOptions
                        .map(
                          (c) => DropdownMenuItem<String>(
                        value: c['value'],
                        child: Text(c['label']!),
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

                  const SizedBox(height: 32),

                  AppButton(
                    text: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: () => _saveProfile(student),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
