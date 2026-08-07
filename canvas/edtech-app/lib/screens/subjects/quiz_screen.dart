import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../../services/database_service.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final VoidCallback? onQuizCompleted;

  const QuizScreen({super.key, required this.quiz, this.onQuizCompleted});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  final Map<String, dynamic> _answers = {};
  bool _isSubmitted = false;
  final DatabaseService _dbService = DatabaseService();

  void _submitQuiz() async {
    int score = 0;
    int totalPoints = 0;

    for (var question in widget.quiz.questions) {
      totalPoints += question.points;
      final userAnswer = _answers[question.id];

      // Basic checking logic
      bool isCorrect = false;
      if (question.type == QuestionType.mcq) {
        // correctAnswer stores the option TEXT, and userAnswer (set in
        // _buildAnswerOptions) is also the selected option TEXT.
        if (userAnswer != null && question.correctAnswer == userAnswer.toString()) {
          isCorrect = true;
        }
      } else {
        // Text match
        if (userAnswer.toString().toLowerCase() ==
            question.correctAnswer.toLowerCase()) {
          isCorrect = true;
        }
      }

      if (isCorrect) {
        score += question.points;
      }

      question.userAnswer = userAnswer.toString();
      question.isCorrect = isCorrect;
    }

    final percentage = (score / totalPoints * 100).round();

    setState(() {
      widget.quiz.isCompleted = true;
      widget.quiz.score = percentage;
      widget.quiz.bestScore = (widget.quiz.bestScore ?? 0) < percentage
          ? percentage
          : widget.quiz.bestScore;
      widget.quiz.totalAttempts += 1;
      _isSubmitted = true;
    });

    await _dbService.updateQuiz(widget.quiz);

    if (widget.onQuizCompleted != null) {
      widget.onQuizCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted || widget.quiz.isCompleted) {
      return _buildResultScreen();
    }

    final question = widget.quiz.questions[_currentQuestionIndex];
    final isLastQuestion =
        _currentQuestionIndex == widget.quiz.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / widget.quiz.questions.length,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${widget.quiz.questions.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            ..._buildAnswerOptions(question),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (isLastQuestion) {
                  _submitQuiz();
                } else {
                  setState(() {
                    _currentQuestionIndex++;
                  });
                }
              },
              child: Text(isLastQuestion ? 'Submit Quiz' : 'Next Question'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnswerOptions(Question question) {
    if (question.type == QuestionType.mcq && question.options != null) {
      return List.generate(question.options!.length, (index) {
        final option = question.options![index];
        final isSelected = _answers[question.id] == option;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _answers[question.id] = option;
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey,
                width: isSelected ? 2 : 1,
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
            ),
            child: Text(option),
          ),
        );
      });
    }

    // Fallback for text input
    return [
      TextField(
        onChanged: (value) {
          _answers[question.id] = value;
        },
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Type your answer here',
        ),
      ),
    ];
  }

  Widget _buildResultScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Score: ${widget.quiz.score}%',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ...widget.quiz.questions.map((q) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: (q.isCorrect ?? false)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.questionText,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Your Answer: ${_getAnswerText(q)}'),
                        Text('Correct Answer: ${_getCorrectAnswerText(q)}'),
                        if (q.explanation != null) ...[
                          const SizedBox(height: 8),
                          Text('Explanation: ${q.explanation}',
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic)),
                        ]
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Subject'),
            )
          ],
        ),
      ),
    );
  }

  String _getAnswerText(Question q) {
    // userAnswer already stores the selected option text (or free-form text
    // for non-MCQ questions).
    return q.userAnswer ?? 'No answer';
  }

  String _getCorrectAnswerText(Question q) {
    // correctAnswer already stores the option text (or free-form text for
    // non-MCQ questions).
    return q.correctAnswer;
  }
}
