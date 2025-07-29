import 'package:flutter/material.dart';
import '../services/font_preference_service.dart';
import '../utils/service_locator.dart';
import '../utils/session_debug_helper.dart';
import 'dart:developer' as developer;
import '../screens/profile_debug_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FontPreferenceService _fontPreferenceService;
  bool _isOpenDyslexicFont = false;
  String _appVersion = 'Loading...';
  String _appName = 'DyslexAI';

  @override
  void initState() {
    super.initState();
    _fontPreferenceService = getIt<FontPreferenceService>();
    _loadFontPreference();
    _loadAppInfo();
  }

  Future<void> _loadFontPreference() async {
    final isOpenDyslexic = await _fontPreferenceService.isOpenDyslexicSelected();
    setState(() {
      _isOpenDyslexicFont = isOpenDyslexic;
    });
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        _appName = packageInfo.appName;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  Future<void> _onFontToggle(bool value) async {
    setState(() {
      _isOpenDyslexicFont = value;
    });
    
    await _fontPreferenceService.setFontPreference(value);
    developer.log('Font preference changed to: ${value ? 'OpenDyslexic' : 'Roboto'}', name: 'dyslexic_ai.settings');
    
    // Show a snackbar to inform user about the change
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Font changed to ${value ? 'OpenDyslexic' : 'Roboto'}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearSessionData() async {
    await SessionDebugHelper.clearAllSessionData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All session data cleared - restart app to see changes'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _resetToNewUser() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to New User'),
        content: const Text(
          'This will completely reset the app to its initial state:\n\n'
          '• Remove your learning profile\n'
          '• Clear all session history\n'
          '• Reset daily streak to 0\n'
          '• Return to "get started" experience\n\n'
          'This action cannot be undone. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SessionDebugHelper.completeResetToNewUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset complete! Restart app to see new user experience'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccessibilitySection(),
          const SizedBox(height: 24),
          _buildDebugSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
        ],
      ),
    );
  }



  Widget _buildAccessibilitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accessibility',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFontSwitchTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSwitchTile() {
    return SwitchListTile(
      title: const Text('OpenDyslexic Font'),
      subtitle: const Text('Use specialized font for better readability'),
      value: _isOpenDyslexicFont,
      onChanged: _onFontToggle,
      secondary: const Icon(Icons.text_fields),
    );
  }



  Widget _buildDebugSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug & Development',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingsTile(
              'Clear Session Data',
              'Reset all session history and progress',
              Icons.delete_forever,
              _clearSessionData,
            ),
            _buildSettingsTile(
              'Reset to New User',
              'Complete reset - return to first-time user experience',
              Icons.refresh,
              _resetToNewUser,
            ),
            _buildSettingsTile(
              'Profile Debug',
              'View AI profile generation status and logs',
              Icons.psychology,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileDebugScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.info, color: Colors.grey[600]),
              title: const Text('Version', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('$_appName $_appVersion', style: const TextStyle(fontSize: 12)),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSettingsTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
} 