import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import '../../models/flashcard.dart';
import '../../services/database_service.dart';

class FlashcardScreen extends StatefulWidget {
  final FlashcardDeck deck;

  const FlashcardScreen({super.key, required this.deck});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int _currentIndex = 0;
  final DatabaseService _dbService = DatabaseService();
  late List<Flashcard> _cards;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _cards = widget.deck.cards;
    widget.deck.lastReviewedAt = DateTime.now();
    widget.deck.totalReviews += 1;
    // Don't save review update yet, save progress as we go or at end?
    // Saving at start for "last reviewed" timestamp
    _dbService.updateFlashcardDeck(widget.deck);
  }

  void _markCard(bool known) {
    setState(() {
      final card = _cards[_currentIndex];
      // Simple spaced repetition logic placeholder
      if (known) {
        card.reviewCount += 1;
        card.interval *= 2; // Simple doubling
        card.isMastered =
            card.reviewCount > 3; // Mastered after 3 successful reviews
      } else {
        card.interval = 1; // Reset
      }
      card.nextReviewDate = DateTime.now().add(Duration(days: card.interval));

      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        _isFinished = true;
        _saveProgress();
      }
    });
  }

  void _saveProgress() async {
    // Recalculate mastery
    int masteredCount = _cards.where((c) => c.isMastered).length;
    widget.deck.masteryPercentage = (masteredCount / _cards.length) * 100;
    await _dbService.updateFlashcardDeck(widget.deck);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deck.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text('Session Complete!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('You have reviewed all ${_cards.length} cards.'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Subject'),
              ),
            ],
          ),
        ),
      );
    }

    final card = _cards[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.deck.title} (${_currentIndex + 1}/${_cards.length})'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: FlipCard(
                direction: FlipDirection.HORIZONTAL,
                front: _buildCardSide(
                    card.front, Colors.blue.shade50, 'Tap to flip'),
                back:
                    _buildCardSide(card.back, Colors.white, 'Tap to flip back'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markCard(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Still Learning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markCard(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Got it!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSide(String text, Color color, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.normal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                hint,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
