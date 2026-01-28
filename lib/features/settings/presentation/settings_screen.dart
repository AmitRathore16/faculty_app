import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/storage_keys.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _initBiometricSettings();
  }

  Future<void> _initBiometricSettings() async {
    // 1) Device biometric availability
    final isAvailable = await BiometricService.isAvailable();

    // 2) User preference stored
    final savedEnabled =
        StorageService.getBool(StorageKeys.biometricEnabled) ?? false;

    if (!mounted) return;

    setState(() {

    });

    // Optional cleanup: if device no longer supports, reset stored pref
    if (!isAvailable && savedEnabled == true) {
      await StorageService.setBool(StorageKeys.biometricEnabled, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          _buildCard([
            _buildSwitchTile(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Enable dark theme',
              value: themeMode == ThemeMode.dark,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setTheme(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ]),
          const SizedBox(height: 24),

          // Security Section
          _buildSectionHeader('Security'),
          _buildCard([
            _buildNavigationTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () {
                context.push('/change-password');
              },
            ),
          ]),
          const SizedBox(height: 24),

          // Notifications Section
          // _buildSectionHeader('Notifications'),
          // _buildCard([
          //   _buildSwitchTile(
          //     icon: Icons.notifications_outlined,
          //     title: 'Push Notifications',
          //     subtitle: 'Receive updates and reminders',
          //     value: _notificationsEnabled,
          //     onChanged: (value) {
          //       setState(() => _notificationsEnabled = value);
          //     },
          //   ),
          // ]),
          // const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildCard([
            _buildNavigationTile(
              icon: Icons.info_outline,
              title: 'About ${AppConfig.appName}',
              subtitle: 'Version ${AppConfig.appVersion}',
              onTap: () {
                _showAboutDialog();
              },
            ),
            const Divider(height: 1),
            _buildNavigationTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildNavigationTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          // Logout
          _buildCard([
            _buildNavigationTile(
              icon: Icons.logout,
              title: 'Logout',
              titleColor: AppColors.error,
              onTap: () async {
                final confirm = await _showConfirmDialog(
                  'Logout',
                  'Are you sure you want to logout?',
                );
                if (confirm && mounted) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (mounted) context.go('/login');
                }
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.grey600,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.primary),
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
      onTap: onTap,
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.appName,
      applicationVersion: AppConfig.appVersion,
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.school, color: Colors.white, size: 32),
      ),
      children: [
        const Text(
          'Faculty Pedia is an educational platform connecting students with top educators.',
        ),
      ],
    );
  }
}
