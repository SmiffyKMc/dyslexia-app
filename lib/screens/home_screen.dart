import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../controllers/learner_profile_store.dart';
import '../controllers/session_log_store.dart';
import '../services/gemma_profile_update_service.dart';
import '../models/session_log.dart';
import '../utils/service_locator.dart';
import '../utils/session_debug_helper.dart';
import '../utils/resource_diagnostics.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LearnerProfileStore _profileStore;
  late final SessionLogStore _sessionLogStore;
  late final GemmaProfileUpdateService _profileUpdateService;
  bool _isRecommendationExpanded = false;

  @override
  void initState() {
    super.initState();
    _profileStore = getIt<LearnerProfileStore>();
    _sessionLogStore = getIt<SessionLogStore>();
    _profileUpdateService = getIt<GemmaProfileUpdateService>();
    
    // DIAGNOSTIC: Log home screen initialization
    ResourceDiagnostics().logMemoryPressureEvent('Home screen initialized', 'HomeScreen.initState');
    ResourceDiagnostics().logDetailedReport();
    
    // DIAGNOSTIC: Set up periodic resource monitoring for crash detection
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        ResourceDiagnostics().checkForLeaks();
        ResourceDiagnostics().logMemoryPressureEvent('Periodic resource check', 'HomeScreen idle monitoring');
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    // DIAGNOSTIC: Log home screen disposal with final resource state
    ResourceDiagnostics().logMemoryPressureEvent('Home screen disposed', 'HomeScreen.dispose');
    ResourceDiagnostics().logDetailedReport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          // Track user activity to defer background AI processing
          onTap: () => _profileUpdateService.markUserActive(),
          onScaleStart: (_) => _profileUpdateService.markUserActive(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Static header - no Observer needed
                _buildHeader(context),
                const SizedBox(height: 16),
                
                // Profile section - only rebuilds when profile changes
                Observer(
                  builder: (context) => _buildLearnerProfile(context),
                ),
                const SizedBox(height: 16),
                
                // Progress section - only rebuilds when session data changes
                Observer(
                  builder: (context) => _buildTodaysProgress(context),
                ),
                const SizedBox(height: 16),
                
                // Suggestions section - only rebuilds when profile changes
                Observer(
                  builder: (context) => _buildPersonalizedSuggestions(context),
                ),
                const SizedBox(height: 16),
                
                // Static tools - no Observer needed
                _buildQuickTools(context),
                const SizedBox(height: 16),
                
                // Recent activity - only rebuilds when session logs change
                Observer(
                  builder: (context) => _buildRecentActivity(),
                ),
                const SizedBox(height: 16), // Extra bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[300],
          child: const Icon(Icons.person, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Observer(
                builder: (context) => Text(
                  _profileStore.currentProfile?.userName != null 
                      ? 'Hello, ${_profileStore.currentProfile!.userName}!'
                      : 'Hello!',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Daily streak: 7 days',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // AI Activity indicator still needs Observer for background processing state
        Observer(
          builder: (context) => _buildAIActivityIndicator(),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined, size: 20),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, size: 20),
            ),
            if (_profileStore.isUpdating)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.3, end: 1.0),
                    builder: (context, value, child) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: value),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                    onEnd: () {
                      if (mounted && _profileStore.isUpdating) {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLearnerProfile(BuildContext context) {
    if (_profileStore.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading your learning profile...'),
            ],
          ),
        ),
      );
    }

    if (!_profileStore.hasProfile) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_outlined, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Learning Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete a few sessions to get personalized recommendations!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Check if this is an initial profile (no real learning sessions)
    final isInitialProfile = _profileStore.isInitialProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Learning Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_profileStore.isUpdating)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Updating...',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_profileStore.needsUpdate && !isInitialProfile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (!isInitialProfile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Up to date',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Show different content based on whether profile has real data
            if (isInitialProfile) ...[
              // Getting started content instead of fake stats
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      color: Theme.of(context).primaryColor,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ready to start learning!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete a few lessons so our AI can learn about your reading abilities and provide personalized recommendations.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Real profile data
              Row(
                children: [
                  Expanded(
                    child: _buildProfileStat(
                      'Confidence',
                      _profileStore.confidenceLevel,
                      context,
                    ),
                  ),
                  Expanded(
                    child: _buildProfileStat(
                      'Accuracy',
                      _profileStore.accuracyLevel,
                      context,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_profileStore.currentFocus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.center_focus_strong,
                        color: Theme.of(context).primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current Focus: ${_profileStore.currentFocus}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Add phoneme confusions
              if (_profileStore.phonemeConfusions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Practice These Sounds',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profileStore.phonemeConfusions.take(3).join(', '),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Add strength areas
              if (_profileStore.strengthAreas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.thumb_up, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Strengths',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profileStore.strengthAreas.take(2).join(', '),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAIActivityIndicator() {
    return RepaintBoundary(
      child: Observer(
        builder: (context) {
          if (!_profileUpdateService.isBackgroundProcessingActive) {
            return const SizedBox.shrink();
          }
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI Learning',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileStat(String label, String value, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysProgress(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Today's Progress",
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See all >',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_sessionLogStore.todaysStudyTime.inMinutes} minutes today',
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Goal: 30 minutes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_sessionLogStore.todaysStudyTime.inMinutes / 30.0).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _sessionLogStore.todaysStudyTime.inMinutes >= 30 
                                  ? Colors.green 
                                  : Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProgressStat(
                  'Sessions', 
                  '${_sessionLogStore.todaysSessionCount}', 
                  context
                ),
                _buildProgressStat(
                  'Accuracy', 
                  '${(_sessionLogStore.todaysAverageAccuracy * 100).round()}%', 
                  context
                ),
                _buildProgressStat(
                  'Study Time', 
                  '${_sessionLogStore.todaysStudyTime.inMinutes}min', 
                  context
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTools(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Learn',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                context,
                'Reading Coach',
                Icons.mic_outlined,
                '/reading_coach',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolCard(
                context,
                'Story Mode',
                Icons.menu_book_outlined,
                '/adaptive_story',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                context,
                'Phonics Game',
                Icons.games_outlined,
                '/phonics_game',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolCard(
                context,
                'Sentence Fixer',
                Icons.search_outlined,
                '/sentence_fixer',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              // Track user activity when navigating to learn screen
              _profileUpdateService.markUserActive();
              Navigator.pushNamed(context, '/learn');
            },
            child: Text(
              'See all learning activities >',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(BuildContext context, String title, IconData icon, String route) {
    return Card(
      child: InkWell(
        onTap: () {
          // Track user activity when navigating to tools
          _profileUpdateService.markUserActive();
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentSessions = _sessionLogStore.recentLogs.take(3).toList();
    
    for (final session in recentSessions) {
      if (session.sessionType == SessionType.readingCoach && 
          (session.data['words_read'] == 0 || session.accuracy == 0)) {
        SessionDebugHelper.debugSessionData(session);
        SessionDebugHelper.validateSessionData(session);
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (recentSessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No recent activity. Start a session to begin learning!',
                    style: TextStyle(color: Colors.grey),
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          )
        else
          ...recentSessions.map((session) => _buildActivityItem(
            _getSessionIcon(session.sessionType),
            session.summaryText,
            _formatSessionTime(session.timestamp),
          )),
      ],
    );
  }

  IconData _getSessionIcon(SessionType sessionType) {
    switch (sessionType) {
      case SessionType.readingCoach:
        return Icons.mic_outlined;
      case SessionType.adaptiveStory:
        return Icons.menu_book_outlined;
      case SessionType.phonicsGame:
        return Icons.games_outlined;
      case SessionType.soundItOut:
        return Icons.volume_up;
      case SessionType.sentenceFixer:
        return Icons.school;
    }
  }

  String _formatSessionTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
  }
  
  Widget _buildActivityItem(IconData icon, String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  time,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedSuggestions(BuildContext context) {
    if (!_profileStore.hasProfile) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suggested Practice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Start with some sessions to get personalized suggestions!",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "Try Reading Coach or Word Doctor",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Personalized for You',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Colors.green[700],
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI Powered',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildExpandableRecommendation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableRecommendation(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isRecommendationExpanded = !_isRecommendationExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: _isRecommendationExpanded ? Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: 2,
          ) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended: ${_profileStore.recommendedTool}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profileStore.learningAdvice,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: _isRecommendationExpanded ? null : 2,
                        overflow: _isRecommendationExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isRecommendationExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            if (_isRecommendationExpanded) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToRecommendedTool(_profileStore.recommendedTool),
                  icon: _getToolIcon(_profileStore.recommendedTool),
                  label: Text('Try ${_profileStore.recommendedTool}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Icon _getToolIcon(String toolName) {
    switch (toolName.toLowerCase()) {
      case 'reading coach':
        return const Icon(Icons.mic_outlined, size: 20);
      case 'adaptive story':
      case 'story mode':
        return const Icon(Icons.menu_book_outlined, size: 20);
      case 'phonics game':
        return const Icon(Icons.games_outlined, size: 20);
      case 'sentence fixer':
        return const Icon(Icons.search_outlined, size: 20);

      case 'word doctor':
        return const Icon(Icons.search_outlined, size: 20);
      default:
        return const Icon(Icons.school, size: 20);
    }
  }

  void _navigateToRecommendedTool(String toolName) {
    switch (toolName.toLowerCase()) {
      case 'reading coach':
        Navigator.of(context).pushNamed('/reading_coach');
        break;
      case 'adaptive story':
      case 'story mode':
        Navigator.of(context).pushNamed('/adaptive_story');
        break;
      case 'phonics game':
        Navigator.of(context).pushNamed('/phonics_game');
        break;
      case 'sentence fixer':
        Navigator.of(context).pushNamed('/sentence_fixer');
        break;

      case 'word doctor':
        Navigator.of(context).pushNamed('/word_doctor');
        break;
      default:
        // Fallback to learn screen for learning activities
        Navigator.of(context).pushNamed('/learn');
        break;
    }
  }

  Future<void> _updateProfile() async {
    await _profileUpdateService.updateProfileFromRecentSessions();
  }
} 