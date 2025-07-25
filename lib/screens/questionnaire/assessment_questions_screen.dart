import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../models/assessment_item.dart';

class AssessmentQuestionsScreen extends StatefulWidget {
  final List<String> selectedChallenges;
  final ValueChanged<List<String>> onChallengesChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AssessmentQuestionsScreen({
    super.key,
    required this.selectedChallenges,
    required this.onChallengesChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<AssessmentQuestionsScreen> createState() => _AssessmentQuestionsScreenState();
}

class _AssessmentQuestionsScreenState extends State<AssessmentQuestionsScreen> {
  late Set<String> _selectedItems;

  @override
  void initState() {
    super.initState();
    try {
      developer.log('🧠 Initializing AssessmentQuestionsScreen...', name: 'dyslexic_ai.questionnaire');
      _selectedItems = Set.from(widget.selectedChallenges);
      developer.log('🧠 Loaded ${AssessmentItem.assessmentItems.length} assessment items', name: 'dyslexic_ai.questionnaire');
      developer.log('🧠 AssessmentQuestionsScreen initialized successfully', name: 'dyslexic_ai.questionnaire');
    } catch (e, stackTrace) {
      developer.log('❌ Failed to initialize AssessmentQuestionsScreen: $e', name: 'dyslexic_ai.questionnaire', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void _toggleItem(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
    widget.onChallengesChanged(_selectedItems.toList());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          
          // Header card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.checklist,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Signs Assessment',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select any challenges you experience. This helps us recommend the best tools for you.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Selected count indicator
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedItems.length} item${_selectedItems.length == 1 ? '' : 's'} selected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          
          // Assessment items by category
          ..._buildCategoryGroups(),
          
          const SizedBox(height: 32),
          
          // Navigation buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Complete Assessment'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryGroups() {
    final groupedItems = <String, List<AssessmentItem>>{};
    
    // Group items by category
    for (final item in AssessmentItem.assessmentItems) {
      if (!groupedItems.containsKey(item.category)) {
        groupedItems[item.category] = [];
      }
      groupedItems[item.category]!.add(item);
    }

    final widgets = <Widget>[];
    
    for (final entry in groupedItems.entries) {
      widgets.add(_buildCategoryCard(entry.key, entry.value));
      widgets.add(const SizedBox(height: 16));
    }
    
    return widgets;
  }

  Widget _buildCategoryCard(String category, List<AssessmentItem> items) {
    final categoryInfo = _getCategoryInfo(category);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: categoryInfo.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    categoryInfo.icon,
                    size: 18,
                    color: categoryInfo.color,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  categoryInfo.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: categoryInfo.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ...items.map((item) => _buildAssessmentItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentItem(AssessmentItem item) {
    final isSelected = _selectedItems.contains(item.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _toggleItem(item.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CategoryInfo _getCategoryInfo(String category) {
    switch (category) {
      case 'reading':
        return _CategoryInfo('Reading & Comprehension', Icons.menu_book, Colors.blue);
      case 'spelling':
        return _CategoryInfo('Spelling & Writing', Icons.edit, Colors.green);
      case 'letters':
        return _CategoryInfo('Letter Recognition', Icons.text_fields, Colors.orange);
      case 'organization':
        return _CategoryInfo('Organization & Memory', Icons.psychology, Colors.purple);
      default:
        return _CategoryInfo('Other', Icons.help, Colors.grey);
    }
  }
}

class _CategoryInfo {
  final String title;
  final IconData icon;
  final Color color;

  _CategoryInfo(this.title, this.icon, this.color);
} 