import 'package:flutter/material.dart';
import '../controllers/session_log_store.dart';
import '../controllers/learner_profile_store.dart';
import '../services/font_preference_service.dart';
import '../utils/service_locator.dart';
import '../utils/session_debug_helper.dart';
import 'dart:developer' as developer;
import '../screens/profile_debug_screen.dart'; // Added import for ProfileDebugScreen
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:math' as math;
import '../services/global_session_manager.dart';

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

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Session Data'),
          content: const Text(
            'This will remove all session history but keep your profile settings. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearSessionData();
              },
              child: const Text('Clear Data'),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset to New User'),
          content: const Text(
            'This will clear ALL data including profile, sessions, and preferences. This cannot be undone. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetToNewUser();
              },
              child: const Text('Reset All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearSessionData() async {
    try {
      final sessionStore = getIt<SessionLogStore>();
      await sessionStore.clearAllLogs();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Session data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to clear session data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetToNewUser() async {
    try {
      final sessionStore = getIt<SessionLogStore>();
      final profileStore = getIt<LearnerProfileStore>();
      
      await sessionStore.clearAllLogs();
      await profileStore.completeResetToNewUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reset complete - restart app to see changes'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reset: $e'),
            backgroundColor: Colors.red,
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
              'Debug Tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingsTile(
              'Profile Debug',
              'View learner profile details',
              Icons.person_outline,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileDebugScreen()),
              ),
            ),
            _buildSettingsTile(
              'Session Debug',
              'View session logs',
              Icons.bug_report,
              () => SessionDebugHelper.debugAllRecentSessions(),
            ),
            _buildSettingsTile(
              'Clear Session Data',
              'Remove all session history',
              Icons.delete_sweep,
              () => _showClearDataDialog(),
            ),
            _buildSettingsTile(
              'Reset to New User',
              'Clear all data and start fresh',
              Icons.refresh,
              () => _showResetDialog(),
            ),
            _buildSettingsTile(
              'Test AI Service',
              'Check if AI model is working',
              Icons.smart_toy,
              () => _testAIService(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testAIService() async {
    try {
      final aiService = getAIInferenceService();
      
      if (aiService == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ AI Service is NULL - Model not initialized!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        developer.log('🚨 AI TEST FAILED: Service is null', name: 'dyslexic_ai.settings');
        return;
      }

      developer.log('🧪 Testing AI service with simple prompt...', name: 'dyslexic_ai.settings');
      
      final response = await aiService.generateResponse(
        'Generate a simple sentence with the word "test": ',
        activity: AIActivity.sentenceGeneration,
      );
      
      developer.log('✅ AI TEST SUCCESS: "${response.substring(0, math.min(50, response.length))}..."', 
          name: 'dyslexic_ai.settings');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ AI Service Working! Response: "${response.substring(0, math.min(30, response.length))}..."'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      developer.log('🚨 AI TEST FAILED with error: $e', name: 'dyslexic_ai.settings');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ AI Test Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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