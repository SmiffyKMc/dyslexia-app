import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../controllers/learner_profile_store.dart';
import '../services/profile_update_service.dart';
import '../utils/service_locator.dart';
import '../utils/theme.dart';
import 'dart:developer' as developer;

class ProfileDebugScreen extends StatefulWidget {
  const ProfileDebugScreen({super.key});

  @override
  State<ProfileDebugScreen> createState() => _ProfileDebugScreenState();
}

class _ProfileDebugScreenState extends State<ProfileDebugScreen> {
  late LearnerProfileStore _profileStore;
  late ProfileUpdateService _profileUpdateService;
  bool _isUpdating = false;
  String? _lastUpdateResult;
  DateTime? _lastUpdateTime;
  List<String> _profileLogs = [];

  @override
  void initState() {
    super.initState();
    _profileStore = getIt<LearnerProfileStore>();
    _profileUpdateService = getIt<ProfileUpdateService>();
    _loadProfileLogs();
  }

  void _loadProfileLogs() {
    // This would ideally load from a persistent log store
    // For now, we'll show current status
    setState(() {
      _profileLogs = [
        'Profile debug screen initialized',
        'Checking for recent profile updates...',
      ];
    });
  }

  Future<void> _triggerProfileUpdate() async {
    setState(() {
      _isUpdating = true;
      _lastUpdateResult = null;
    });

    try {
      developer.log('🧠 Manual profile update triggered',
          name: 'dyslexic_ai.profile_debug');

      final success =
          await _profileUpdateService.updateProfileFromRecentSessions();

      setState(() {
        _isUpdating = false;
        _lastUpdateResult =
            success ? 'Profile updated successfully' : 'Profile update failed';
        _lastUpdateTime = DateTime.now();
        _profileLogs
            .add('${DateTime.now().toIso8601String()}: $_lastUpdateResult');
      });

      developer.log('🧠 Manual profile update completed: $success',
          name: 'dyslexic_ai.profile_debug');
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _lastUpdateResult = 'Error: $e';
        _lastUpdateTime = DateTime.now();
        _profileLogs.add('${DateTime.now().toIso8601String()}: Error - $e');
      });

      developer.log('🧠 Manual profile update failed: $e',
          name: 'dyslexic_ai.profile_debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Debug'),
        backgroundColor: DyslexiaTheme.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: Observer(
        builder: (context) {
          final profile = _profileStore.currentProfile;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Profile Status
                _buildProfileStatusCard(profile),

                const SizedBox(height: 16),

                // Profile Update Controls
                _buildUpdateControlsCard(),

                const SizedBox(height: 16),

                // Profile Update Logs
                _buildProfileLogsCard(),

                const SizedBox(height: 16),

                // Profile Details
                if (profile != null) _buildProfileDetailsCard(profile),
                
                // Extra bottom space for comfortable scrolling
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileStatusCard(dynamic profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Profile Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Profile Loaded', profile != null),
            _buildStatusRow('AI Service Available', true),
            _buildStatusRow('Recent Sessions Available', true),
            if (_lastUpdateTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last Update: ${_formatDateTime(_lastUpdateTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.refresh, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Profile Update Controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lastUpdateResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastUpdateResult!.contains('successfully')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastUpdateResult!.contains('successfully')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(
                  _lastUpdateResult!,
                  style: TextStyle(
                    color: _lastUpdateResult!.contains('successfully')
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _triggerProfileUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DyslexiaTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isUpdating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Updating Profile...'),
                        ],
                      )
                    : const Text('Trigger Profile Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileLogsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Profile Update Logs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _profileLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _profileLogs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard(dynamic profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Current Profile Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Focus: ${profile.focus}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${profile.confidence}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Recommended Tool: ${profile.recommendedTool}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Advice: ${profile.advice}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isActive) {
    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.cancel,
          color: isActive ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
