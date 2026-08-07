import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:uuid/uuid.dart';
import '../../services/openai_rag_service.dart';
import '../../services/openai_config_service.dart';
import '../../services/database_service.dart';
import '../../models/flashcard.dart';
import '../settings/openai_api_key_screen.dart';

class FlashcardGenerationScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final Color subjectColor;
  final String? storeName;

  const FlashcardGenerationScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
    this.storeName,
  });

  @override
  State<FlashcardGenerationScreen> createState() =>
      _FlashcardGenerationScreenState();
}

class _FlashcardGenerationScreenState extends State<FlashcardGenerationScreen> {
  OpenAIRagService? _ragService;
  bool _needsApiKey = false;
  bool _isGenerating = false;
  List<FlashcardItem>? _flashcards;
  int _currentCardIndex = 0;
  int _numberOfCards = 10;

  @override
  void initState() {
    super.initState();
    _initRagService();
  }

  Future<void> _initRagService() async {
    final apiKey = await OpenAIConfigService.getApiKey();
    if (apiKey == null) {
      if (mounted) setState(() => _needsApiKey = true);
      return;
    }

    final service = OpenAIRagService(apiKey);
    if (widget.storeName != null) {
      service.setStoreForSubject(widget.subjectId, widget.storeName!);
    }
    if (mounted) {
      setState(() {
        _ragService = service;
        _needsApiKey = false;
      });
    }
  }

  Future<void> _promptForApiKey() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OpenAIApiKeyScreen()),
    );
    if (result == true) {
      _initRagService();
    }
  }

  Future<void> _generateFlashcards() async {
    if (_ragService == null) {
      _promptForApiKey();
      return;
    }

    setState(() {
      _isGenerating = true;
      _flashcards = null;
      _currentCardIndex = 0;
    });

    try {
      final result = await _ragService!.generateFlashcards(
        subjectId: widget.subjectId,
        numberOfCards: _numberOfCards,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      final cardsData = result['flashcards'] as List;
      final flashcards =
          cardsData.map((c) => FlashcardItem.fromJson(c)).toList();

      // Save to database
      await _saveFlashcardsToDatabase(flashcards);

      setState(() {
        _flashcards = flashcards;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        final isAuthError = e.toString().toLowerCase().contains('api key');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating flashcards: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: isAuthError
                ? SnackBarAction(
                    label: 'Update Key',
                    textColor: Colors.white,
                    onPressed: _promptForApiKey,
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _saveFlashcardsToDatabase(List<FlashcardItem> items) async {
    try {
      final deckId = const Uuid().v4();
      final List<Flashcard> dbCards = items
          .map((item) => Flashcard(
                id: const Uuid().v4(),
                front: item.front,
                back: item.back,
                createdAt: DateTime.now(),
                nextReviewDate: DateTime.now(),
              ))
          .toList();

      final deck = FlashcardDeck(
        id: deckId,
        subjectId: widget.subjectId,
        title: 'AI Flashcards - ${DateTime.now().toString().split(' ')[0]}',
        cards: dbCards,
        createdAt: DateTime.now(),
        lastReviewedAt: DateTime.now(),
      );

      await DatabaseService().saveFlashcardDeck(deck);
      print('✅ Flashcard deck saved to database: $deckId');
    } catch (e) {
      print('❌ Error saving flashcards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Flashcard Generator',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _needsApiKey
          ? _buildNeedsApiKeyScreen(isDark)
          : (_flashcards == null
              ? _buildSetupScreen(isDark)
              : _buildFlashcardView(isDark)),
    );
  }

  Widget _buildNeedsApiKeyScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_key_off_rounded, size: 64, color: widget.subjectColor),
            const SizedBox(height: 24),
            Text(
              'OpenAI API Key Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your OpenAI API key to generate AI-powered flashcards.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _promptForApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.subjectColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Add API Key'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupScreen(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.subjectColor.withOpacity(0.2),
                  widget.subjectColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.style_rounded, color: widget.subjectColor, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Flashcards',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Master concepts with AI-generated cards',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Number of Cards',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [5, 10, 15, 20].map((num) {
              final isSelected = _numberOfCards == num;
              return ChoiceChip(
                label: Text('$num'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _numberOfCards = num);
                },
                selectedColor: widget.subjectColor,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateFlashcards,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.subjectColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isGenerating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Generate Flashcards',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardView(bool isDark) {
    final card = _flashcards![_currentCardIndex];

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentCardIndex + 1) / _flashcards!.length,
          backgroundColor: widget.subjectColor.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation(widget.subjectColor),
          minHeight: 4,
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Card ${_currentCardIndex + 1}/${_flashcards!.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.subjectColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 400,
                    width: double.infinity,
                    child: FlipCard(
                      direction: FlipDirection.HORIZONTAL,
                      front: _buildCardSide(card.front, 'Question', isDark),
                      back: _buildCardSide(card.back, 'Answer', isDark),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tap card to flip',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (_currentCardIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentCardIndex--);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: widget.subjectColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Previous',
                        style: TextStyle(
                            color: widget.subjectColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (_currentCardIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentCardIndex < _flashcards!.length - 1) {
                        setState(() => _currentCardIndex++);
                      } else {
                        // Finish reviewing
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.subjectColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentCardIndex < _flashcards!.length - 1
                          ? 'Next'
                          : 'Finish',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardSide(String text, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: widget.subjectColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.subjectColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class FlashcardItem {
  final String front;
  final String back;

  FlashcardItem({required this.front, required this.back});

  factory FlashcardItem.fromJson(Map<String, dynamic> json) {
    return FlashcardItem(
      front: json['front'] ?? '',
      back: json['back'] ?? '',
    );
  }
}
