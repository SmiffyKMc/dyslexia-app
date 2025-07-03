import 'package:flutter/material.dart';
import '../services/font_preference_service.dart';
import '../utils/service_locator.dart';
import 'dart:developer' as developer;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FontPreferenceService _fontPreferenceService;
  bool _isOpenDyslexicFont = false;

  @override
  void initState() {
    super.initState();
    _fontPreferenceService = getIt<FontPreferenceService>();
    _loadFontPreference();
  }

  Future<void> _loadFontPreference() async {
    final isOpenDyslexic = await _fontPreferenceService.isOpenDyslexicSelected();
    setState(() {
      _isOpenDyslexicFont = isOpenDyslexic;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileSection(),
          const SizedBox(height: 24),
          _buildAccessibilitySection(),
          const SizedBox(height: 24),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          _buildNotificationSection(),
          const SizedBox(height: 24),
          _buildDataSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildListTile(
              'Name',
              'Reading Assistant User',
              Icons.person,
              () {},
            ),
            _buildListTile(
              'Age',
              'Not specified',
              Icons.cake,
              () {},
            ),
            _buildListTile(
              'Reading Level',
              'Beginner',
              Icons.school,
              () {},
            ),
          ],
        ),
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
            _buildSwitchTile(
              'Increased Letter Spacing',
              'Add extra space between letters',
              true,
              Icons.space_bar,
            ),
            _buildSwitchTile(
              'High Contrast Mode',
              'Enhance text visibility',
              false,
              Icons.contrast,
            ),
            _buildSwitchTile(
              'Word Highlighting',
              'Highlight words while reading',
              true,
              Icons.highlight,
            ),
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

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildListTile(
              'Theme',
              'Light',
              Icons.palette,
              () {},
            ),
            _buildListTile(
              'Text Size',
              'Large',
              Icons.text_increase,
              () {},
            ),
            _buildListTile(
              'Reading Speed',
              'Normal',
              Icons.speed,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              'Daily Reminders',
              'Get reminded to practice daily',
              true,
              Icons.notifications,
            ),
            _buildSwitchTile(
              'Achievement Alerts',
              'Celebrate your progress',
              true,
              Icons.emoji_events,
            ),
            _buildSwitchTile(
              'Weekly Reports',
              'Review your weekly progress',
              false,
              Icons.analytics,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data & Privacy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildListTile(
              'Export Data',
              'Download your progress data',
              Icons.download,
              () {},
            ),
            _buildListTile(
              'Delete Account',
              'Permanently delete your account',
              Icons.delete_forever,
              () {},
              isDestructive: true,
            ),
            _buildListTile(
              'Privacy Policy',
              'Read our privacy policy',
              Icons.privacy_tip,
              () {},
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
            _buildListTile(
              'Version',
              '1.0.0',
              Icons.info,
              () {},
            ),
            _buildListTile(
              'Help & Support',
              'Get help using the app',
              Icons.help,
              () {},
            ),
            _buildListTile(
              'Rate App',
              'Leave a review',
              Icons.star,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: (newValue) {},
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildListTile(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? Colors.red : Colors.grey[600],
      ),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
} 