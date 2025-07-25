class AssessmentItem {
  final String id;
  final String text;
  final String category;
  final String focusArea;

  const AssessmentItem({
    required this.id,
    required this.text,
    required this.category,
    required this.focusArea,
  });

  static const List<AssessmentItem> assessmentItems = [
    // Reading challenges
    AssessmentItem(
      id: 'slow_reading',
      text: 'Reading feels slow or effortful',
      category: 'reading',
      focusArea: 'Reading Coach',
    ),
    AssessmentItem(
      id: 'skipping_words',
      text: 'Often skips words or lines when reading',
      category: 'reading',
      focusArea: 'Reading Coach',
    ),
    AssessmentItem(
      id: 'comprehension_issues',
      text: 'Difficulty understanding what was read',
      category: 'reading',
      focusArea: 'Text Simplifier',
    ),
    AssessmentItem(
      id: 'rereading_often',
      text: 'Needs to reread text multiple times',
      category: 'reading',
      focusArea: 'Text Simplifier',
    ),

    // Spelling challenges
    AssessmentItem(
      id: 'spelling_errors',
      text: 'Frequent spelling mistakes',
      category: 'spelling',
      focusArea: 'Sentence Fixer',
    ),
    AssessmentItem(
      id: 'phonetic_spelling',
      text: 'Spells words as they sound',
      category: 'spelling',
      focusArea: 'Phonics Game',
    ),
    AssessmentItem(
      id: 'inconsistent_spelling',
      text: 'Spells the same word differently',
      category: 'spelling',
      focusArea: 'Word Doctor',
    ),

    // Letter and word challenges  
    AssessmentItem(
      id: 'letter_confusion',
      text: 'Confuses similar letters (b/d, p/q)',
      category: 'letters',
      focusArea: 'Phonics Game',
    ),
    AssessmentItem(
      id: 'word_recognition',
      text: 'Difficulty recognizing common words',
      category: 'letters',
      focusArea: 'Word Doctor',
    ),
    AssessmentItem(
      id: 'sound_letter_connection',
      text: 'Trouble connecting sounds to letters',
      category: 'letters',
      focusArea: 'Phonics Game',
    ),

    // Organization challenges
    AssessmentItem(
      id: 'sequence_difficulty',
      text: 'Difficulty with sequences (days, months)',
      category: 'organization',
      focusArea: 'Text Simplifier',
    ),
    AssessmentItem(
      id: 'time_management',
      text: 'Struggles with time management',
      category: 'organization',
      focusArea: 'Text Simplifier',
    ),
    AssessmentItem(
      id: 'following_instructions',
      text: 'Difficulty following multi-step instructions',
      category: 'organization',
      focusArea: 'Sentence Fixer',
    ),

    // Memory challenges
    AssessmentItem(
      id: 'short_term_memory',
      text: 'Forgets instructions quickly',
      category: 'memory',
      focusArea: 'Text Simplifier',
    ),
    AssessmentItem(
      id: 'word_retrieval',
      text: 'Knows the word but can\'t recall it',
      category: 'memory',
      focusArea: 'Word Doctor',
    ),
  ];
} 