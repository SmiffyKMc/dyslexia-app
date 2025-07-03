class WordAnalysis {
  final String word;
  final List<String> syllables;
  final List<String> phonemes;
  final String mnemonic;
  final String exampleSentence;
  final DateTime analyzedAt;
  final bool isSaved;

  const WordAnalysis({
    required this.word,
    required this.syllables,
    required this.phonemes,
    required this.mnemonic,
    required this.exampleSentence,
    required this.analyzedAt,
    this.isSaved = false,
  });

  WordAnalysis copyWith({
    String? word,
    List<String>? syllables,
    List<String>? phonemes,
    String? mnemonic,
    String? exampleSentence,
    DateTime? analyzedAt,
    bool? isSaved,
  }) {
    return WordAnalysis(
      word: word ?? this.word,
      syllables: syllables ?? this.syllables,
      phonemes: phonemes ?? this.phonemes,
      mnemonic: mnemonic ?? this.mnemonic,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'syllables': syllables,
      'phonemes': phonemes,
      'mnemonic': mnemonic,
      'exampleSentence': exampleSentence,
      'analyzedAt': analyzedAt.toIso8601String(),
      'isSaved': isSaved,
    };
  }

  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    return WordAnalysis(
      word: json['word'] as String,
      syllables: List<String>.from(json['syllables'] as List),
      phonemes: List<String>.from(json['phonemes'] as List),
      mnemonic: json['mnemonic'] as String,
      exampleSentence: json['exampleSentence'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
      isSaved: json['isSaved'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'WordAnalysis(word: $word, syllables: $syllables, phonemes: $phonemes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordAnalysis && other.word == word;
  }

  @override
  int get hashCode => word.hashCode;
} 