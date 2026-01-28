import 'package:faculty_pedia/core/services/api_service.dart';
import 'package:faculty_pedia/shared/models/student_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/user_widgets.dart';
import '../../auth/providers/auth_provider.dart';

/// ✅ Student profile provider (dynamic from backend)
final studentProfileProvider = FutureProvider.autoDispose<Student>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.user;

  if (user == null) throw Exception("Please login");

  final api = ApiService();
  final res = await api.get('/api/students/${user.id}');

  dynamic data = res.data;
  if (data is Map && data['data'] != null) {
    data = data['data'];
  }

  return Student.fromJson(Map<String, dynamic>.from(data));
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentProfileProvider);
          await ref.read(studentProfileProvider.future);
        },
        child: studentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Icon(Icons.error_outline, size: 50, color: AppColors.error),
              const SizedBox(height: 10),
              const Center(child: Text("Failed to load profile")),
              const SizedBox(height: 10),
              Center(child: Text(e.toString())),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(studentProfileProvider),
                  child: const Text("Retry"),
                ),
              ),
            ],
          ),
          data: (student) {
            final courseCount = student.courses.length;
            final testCount = student.results.length;
            final followingCount = student.followingEducators.length;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // ✅ NEW UI HEADER (KEEP THIS)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        UserAvatar(
                          imageUrl: student.imageUrl,
                          name: student.displayName,
                          size: 100,
                          showBorder: true,
                          borderColor: Colors.white,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          student.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),

                        if ((student.username?.isNotEmpty ?? false))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              "@${student.username}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        if ((student.bio?.isNotEmpty ?? false))
                          Text(
                            student.bio!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ✅ Stats (same as before)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('Courses', courseCount.toString()),
                          _buildStatDivider(),
                          _buildStatItem('Tests', testCount.toString()),
                          _buildStatDivider(),
                          _buildStatItem('Following', followingCount.toString()),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Important Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ProfileDetailsCard(student: student),
                  ),

                  const SizedBox(height: 10),

                  // ✅ OLD MENU BUTTONS UI (KEEP EXACTLY THIS)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: () async {
                            await context.push('/edit-profile');
                            ref.invalidate(studentProfileProvider);
                          },
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.play_circle_outline,
                          title: 'My Courses',
                          onTap: () => context.push('/my-courses'),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.assignment_outlined,
                          title: 'My Test Results',
                          onTap: () => context.push('/my-test-results'),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.favorite_outline,
                          title: 'Following Educators',
                          onTap: () => context.push('/following-educators'),
                        ),
                        // _buildMenuItem(
                        //   context,
                        //   icon: Icons.notifications_outlined,
                        //   title: 'Notifications',
                        //   onTap: () {},
                        // ),
                        _buildMenuItem(
                          context,
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),
                        _buildMenuItem(
                          context,
                          icon: Icons.logout,
                          title: 'Logout',
                          titleColor: AppColors.error,
                          iconColor: AppColors.error,
                          onTap: () async {
                            final confirm = await _showLogoutDialog(context);
                            if (confirm && context.mounted) {
                              await ref.read(authStateProvider.notifier).logout();
                              context.go('/login');
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.grey600)),
      ],
    );
  }

  static Widget _buildStatDivider() {
    return Container(width: 1, height: 38, color: AppColors.grey300);
  }

  static Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color? titleColor,
        Color? iconColor,
      }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.grey700),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.grey400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  static Future<bool> _showLogoutDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  final Student student;
  const _ProfileDetailsCard({required this.student});

  @override
  Widget build(BuildContext context) {
    String formatDate(DateTime? d) {
      if (d == null) return "-";
      return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
    }

    Widget row({
      required IconData icon,
      required String title,
      required String value,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: AppColors.grey600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row(icon: Icons.email_outlined, title: "Email", value: student.email),
            Divider(color: AppColors.grey200),

            row(
              icon: Icons.phone_outlined,
              title: "Mobile",
              value: student.mobileNumber ?? "-",
            ),
            Divider(color: AppColors.grey200),

            row(
              icon: Icons.school_outlined,
              title: "Specialization",
              value: student.specialization ?? "-",
            ),
            Divider(color: AppColors.grey200),

            row(
              icon: Icons.class_outlined,
              title: "Class",
              value: student.academicClass ?? "-",
            ),
            Divider(color: AppColors.grey200),

            row(
              icon: Icons.calendar_month_outlined,
              title: "Joined",
              value: formatDate(student.joinedAt),
            ),
          ],
        ),
      ),
    );
  }
}
