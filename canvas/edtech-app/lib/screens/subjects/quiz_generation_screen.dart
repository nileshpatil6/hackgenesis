import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/openai_rag_service.dart';
import '../../services/openai_config_service.dart';
import '../../services/database_service.dart';
import '../../models/quiz.dart';
import '../settings/openai_api_key_screen.dart';
import '../../utils/app_theme.dart';

class QuizGenerationScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final Color subjectColor;
  final String? storeName;

  const QuizGenerationScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
    this.storeName,
  });

  @override
  State<QuizGenerationScreen> createState() => _QuizGenerationScreenState();
}

class _QuizGenerationScreenState extends State<QuizGenerationScreen> {
  OpenAIRagService? _ragService;
  bool _needsApiKey = false;
  bool _isGenerating = false;
  List<QuizQuestion>? _questions;
  int _currentQuestionIndex = 0;
  Map<int, int> _userAnswers = {};
  bool _showResults = false;

  int _numberOfQuestions = 5;
  String _difficulty = 'Medium';

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

  Future<void> _generateQuiz() async {
    if (_ragService == null) {
      _promptForApiKey();
      return;
    }

    setState(() {
      _isGenerating = true;
      _questions = null;
      _userAnswers = {};
      _showResults = false;
    });

    try {
      final result = await _ragService!.generateQuiz(
        subjectId: widget.subjectId,
        numberOfQuestions: _numberOfQuestions,
        difficulty: _difficulty,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      final questionsData = result['questions'] as List;
      final questions =
          questionsData.map((q) => QuizQuestion.fromJson(q)).toList();

      // Save to database
      await _saveQuizToDatabase(questions);

      setState(() {
        _questions = questions;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        final isAuthError = e.toString().toLowerCase().contains('api key');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating quiz: $e'),
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

  Future<void> _saveQuizToDatabase(List<QuizQuestion> questions) async {
    try {
      final quizId = const Uuid().v4();
      final List<Question> dbQuestions = questions.map((q) {
        // Ensure correct answer index is valid
        final correctIndex =
            q.correctAnswer >= 0 && q.correctAnswer < q.options.length
                ? q.correctAnswer
                : 0;

        return Question(
          id: const Uuid().v4(),
          questionType: 0, // MCQ
          questionText: q.question,
          options: q.options,
          correctAnswer: q.options[correctIndex],
          explanation: q.explanation,
          difficultyLevel:
              _difficulty == 'Easy' ? 1 : (_difficulty == 'Medium' ? 3 : 5),
        );
      }).toList();

      final quiz = Quiz(
        id: quizId,
        subjectId: widget.subjectId,
        lessonId: 'generated',
        title:
            'AI Quiz - $_difficulty - ${DateTime.now().toString().split(' ')[0]}',
        questions: dbQuestions,
        createdAt: DateTime.now(),
      );

      await DatabaseService().saveQuiz(quiz);
      print('✅ Quiz saved to database: $quizId');
    } catch (e) {
      print('❌ Error saving quiz: $e');
    }
  }

  void _submitQuiz() {
    setState(() => _showResults = true);
  }

  int get _score {
    int correct = 0;
    _userAnswers.forEach((questionIndex, answerIndex) {
      if (_questions![questionIndex].correctAnswer == answerIndex) {
        correct++;
      }
    });
    return correct;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.inkBackground : AppTheme.paperSunken,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.inkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quiz Generator',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _needsApiKey
          ? _buildNeedsApiKeyScreen(isDark)
          : (_questions == null
              ? _buildSetupScreen(isDark)
              : _buildQuizScreen(isDark)),
    );
  }

  Widget _buildNeedsApiKeyScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_key_off_rounded,
                size: 64, color: widget.subjectColor),
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
              'Add your OpenAI API key to generate AI-powered quizzes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _promptForApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.subjectColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
                Icon(Icons.quiz_rounded, color: widget.subjectColor, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Quiz',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Test your knowledge with AI-generated questions',
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
            'Number of Questions',
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
              final isSelected = _numberOfQuestions == num;
              return ChoiceChip(
                label: Text('$num'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _numberOfQuestions = num);
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
          const SizedBox(height: 24),
          Text(
            'Difficulty Level',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['Easy', 'Medium', 'Hard'].map((level) {
              final isSelected = _difficulty == level;
              return ChoiceChip(
                label: Text(level),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _difficulty = level);
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
              onPressed: _isGenerating ? null : _generateQuiz,
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
                      'Generate Quiz',
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

  Widget _buildQuizScreen(bool isDark) {
    if (_showResults) {
      return _buildResultsScreen(isDark);
    }

    final question = _questions![_currentQuestionIndex];

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions!.length,
          backgroundColor: widget.subjectColor.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation(widget.subjectColor),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}/${_questions!.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.subjectColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  question.question,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                ...List.generate(question.options.length, (index) {
                  final isSelected =
                      _userAnswers[_currentQuestionIndex] == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _userAnswers[_currentQuestionIndex] = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.subjectColor.withOpacity(0.1)
                              : (isDark ? AppTheme.inkSurface : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? widget.subjectColor
                                : (isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1)),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? widget.subjectColor
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? widget.subjectColor
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                question.options[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inkSurface : Colors.white,
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
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentQuestionIndex--);
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
                if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _userAnswers.containsKey(_currentQuestionIndex)
                        ? () {
                            if (_currentQuestionIndex <
                                _questions!.length - 1) {
                              setState(() => _currentQuestionIndex++);
                            } else {
                              _submitQuiz();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.subjectColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentQuestionIndex < _questions!.length - 1
                          ? 'Next'
                          : 'Submit',
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

  Widget _buildResultsScreen(bool isDark) {
    final percentage = (_score / _questions!.length * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.subjectColor.withOpacity(0.2),
                  widget.subjectColor.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Column(
              children: [
                Icon(
                  percentage >= 70
                      ? Icons.emoji_events_rounded
                      : Icons.lightbulb_outline_rounded,
                  size: 64,
                  color: widget.subjectColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: widget.subjectColor,
                  ),
                ),
                Text(
                  '$_score/${_questions!.length} Correct',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            percentage >= 70 ? 'Great Job!' : 'Keep Practicing!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(_questions!.length, (index) {
            final question = _questions![index];
            final userAnswer = _userAnswers[index];
            final isCorrect = userAnswer == question.correctAnswer;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.inkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.question,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Correct Answer: ${question.options[question.correctAnswer]}',
                    style: const TextStyle(color: Colors.green),
                  ),
                  if (!isCorrect && userAnswer != null)
                    Text(
                      'Your Answer: ${question.options[userAnswer]}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (question.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      question.explanation,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _questions = null;
                  _userAnswers = {};
                  _showResults = false;
                  _currentQuestionIndex = 0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.subjectColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Generate New Quiz',
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
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }
}
