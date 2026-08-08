import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../models/subject.dart';
import '../../models/note.dart';
import '../../models/quiz.dart';
import '../../models/flashcard.dart';
import '../../services/openai_rag_service.dart';
import '../../services/openai_config_service.dart';
import '../../services/database_service.dart';
import '../../providers/subject_provider.dart';
import '../../utils/app_theme.dart';
import '../settings/openai_api_key_screen.dart';
import '../subjects/quiz_screen.dart';
import '../subjects/flashcard_screen.dart';
import 'subject_chat_screen.dart';
import 'quiz_generation_screen.dart';
import 'voice_tutor_screen.dart';
import 'flashcard_generation_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;
  final int initialTabIndex;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    this.initialTabIndex = 0,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  OpenAIRagService? _ragService;
  final DatabaseService _dbService = DatabaseService();
  bool _isInitializing = false;
  bool _isStoreReady = false;
  bool _needsApiKey = false;
  String? _storeName;
  final List<String> _uploadedFiles = [];

  // Data from database
  List<Note> _notes = [];
  List<Quiz> _quizzes = [];
  List<FlashcardDeck> _flashcards = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    // Rebuild on tab change so the secondary FAB reflects the active tab.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeStore();
    _loadSubjectData();
  }

  Future<void> _loadSubjectData() async {
    setState(() => _isLoadingData = true);
    try {
      final notes = await _dbService.getNotesForSubject(widget.subject.id);
      final quizzes = await _dbService.getQuizzesForSubject(widget.subject.id);
      final flashcards =
          await _dbService.getFlashcardsForSubject(widget.subject.id);
      // These awaits can outlive the screen (a slow or failing network call
      // while the user navigates back), so the widget may already be gone.
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _quizzes = quizzes;
        _flashcards = flashcards;
        _uploadedFiles.clear();
        _uploadedFiles.addAll(notes.map((n) => n.title));
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading subject data: $e');
      if (!mounted) return;
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _initializeStore() async {
    setState(() {
      _isInitializing = true;
      _needsApiKey = false;
    });

    final apiKey = await OpenAIConfigService.getApiKey();
    if (apiKey == null) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isStoreReady = false;
        _needsApiKey = true;
      });
      return;
    }

    _ragService = OpenAIRagService(apiKey);
    final storeName = await _ragService!.initializeSubjectStore(
      widget.subject.id,
      widget.subject.name,
    );

    if (!mounted) return;
    setState(() {
      _storeName = storeName;
      _isStoreReady = storeName != null;
      _isInitializing = false;
    });

    if (storeName == null && mounted) {
      final isAuthError = _isAuthError(_ragService?.lastError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_ragService?.lastError ?? 'Could not connect to OpenAI.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: isAuthError ? 'Update Key' : 'Retry',
            textColor: Colors.white,
            onPressed: isAuthError ? _promptForApiKey : _initializeStore,
          ),
        ),
      );
    }
  }

  /// Whether a RAG service error looks like the API key itself is the
  /// problem (wrong/revoked key), so the user should be sent to re-enter it
  /// rather than blindly retrying the same key.
  bool _isAuthError(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('api key') || lower.contains('unauthorized');
  }

  Future<void> _promptForApiKey() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OpenAIApiKeyScreen()),
    );
    if (result == true) {
      _initializeStore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadFile() async {
    if (_needsApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add your OpenAI API key to use AI features.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Add Key',
            textColor: Colors.white,
            onPressed: _promptForApiKey,
          ),
        ),
      );
      return;
    }

    if (_isInitializing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setting up storage... Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isStoreReady) {
      final isAuthError = _isAuthError(_ragService?.lastError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ragService?.lastError ?? 'Storage isn\'t ready yet.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: isAuthError ? 'Update Key' : 'Retry',
            textColor: Colors.white,
            onPressed: isAuthError ? _promptForApiKey : _initializeStore,
          ),
        ),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && mounted) {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        List<String> successfulUploads = [];
        List<String> failedUploads = [];

        for (var file in result.files) {
          if (file.path != null) {
            final pdfFile = File(file.path!);
            final success = await _ragService!.uploadPdfToSubject(
              widget.subject.id,
              pdfFile,
            );

            if (success) {
              successfulUploads.add(file.name);
            } else {
              failedUploads.add(file.name);
            }
          }
        }

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Update state
        setState(() {
          _uploadedFiles.addAll(successfulUploads);
        });

        // Show result
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                successfulUploads.isNotEmpty
                    ? '✅ Uploaded ${successfulUploads.length} file(s)\n${failedUploads.isNotEmpty ? "❌ Failed: ${failedUploads.length}" : ""}'
                    : '❌ All uploads failed${_ragService?.lastError != null ? ": ${_ragService!.lastError}" : ""}',
              ),
              backgroundColor:
                  successfulUploads.isNotEmpty ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectColor =
        Color(int.parse('0xFF${widget.subject.color.replaceAll('#', '')}'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.inkBackground : AppTheme.paperSunken,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, subjectColor, isDark),
            const SizedBox(height: 8),
            _buildTabBar(context, subjectColor, isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Notes Tab
                  _uploadedFiles.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.note_add_outlined,
                          title: 'No Notes Yet',
                          message:
                              'Upload PDF files to start studying with AI.',
                          buttonText: 'Upload PDFs',
                          onPressed: _uploadFile,
                          color: subjectColor,
                          isDark: isDark,
                        )
                      : _buildNotesView(isDark, subjectColor),

                  // Learn/Chat Tab
                  _uploadedFiles.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI Chat',
                          message:
                              'Upload PDFs first to chat with your AI tutor.',
                          buttonText: 'Upload PDFs',
                          onPressed: _uploadFile,
                          color: subjectColor,
                          isDark: isDark,
                        )
                      : _buildChatButton(isDark, subjectColor),

                  // Quiz Tab
                  _uploadedFiles.isEmpty && _quizzes.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.quiz_outlined,
                          title: 'Quizzes',
                          message:
                              'Upload PDFs to generate AI-powered quizzes.',
                          buttonText: 'Upload PDFs',
                          onPressed: _uploadFile,
                          color: subjectColor,
                          isDark: isDark,
                        )
                      : _buildQuizList(isDark, subjectColor),

                  // Flashcards Tab
                  _uploadedFiles.isEmpty && _flashcards.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.style_outlined,
                          title: 'Flashcards',
                          message: 'Upload PDFs to generate smart flashcards.',
                          buttonText: 'Upload PDFs',
                          onPressed: _uploadFile,
                          color: subjectColor,
                          isDark: isDark,
                        )
                      : _buildFlashcardList(isDark, subjectColor),

                  // Voice Tab
                  _buildEmptyState(
                    icon: Icons.mic_none_rounded,
                    title: 'Voice Tutor',
                    message: 'Have a conversation with your AI tutor.',
                    buttonText: 'Start Session',
                    onPressed: _openVoiceTutor,
                    color: subjectColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Every empty state already renders its own "Upload PDFs" call to
      // action, so showing the button again as a FAB duplicated it and the
      // two overlapped in the corner. The FAB only appears once a tab has
      // content and the inline button is gone.
      floatingActionButton: _buildFab(subjectColor),
    );
  }

  /// Whether the visible tab is currently showing its empty state.
  bool get _activeTabIsEmpty {
    switch (_tabController.index) {
      case 0:
      case 1:
        return _uploadedFiles.isEmpty;
      case 2:
        return _uploadedFiles.isEmpty && _quizzes.isEmpty;
      case 3:
        return _uploadedFiles.isEmpty && _flashcards.isEmpty;
      default:
        return false;
    }
  }

  Widget? _buildFab(Color subjectColor) {
    if (_activeTabIsEmpty) return null;

    final isNotes = _tabController.index == 0;
    return FloatingActionButton.extended(
      onPressed:
          isNotes ? _uploadFile : () => _onSecondaryFabPressed(subjectColor),
      backgroundColor: subjectColor,
      icon: Icon(
        isNotes ? Icons.upload_file_rounded : Icons.add_rounded,
        color: Colors.white,
      ),
      label: Text(
        isNotes ? 'Upload' : 'Create',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevation: 4,
    );
  }

  void _openVoiceTutor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceTutorScreen(subject: widget.subject),
      ),
    );
  }

  Future<void> _onSecondaryFabPressed(Color subjectColor) async {
    switch (_tabController.index) {
      case 1: // Learn/Chat tab
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectChatScreen(
              subjectId: widget.subject.id,
              subjectName: widget.subject.name,
              subjectColor: subjectColor,
              storeName: _storeName,
            ),
          ),
        );
        break;
      case 2: // Quiz tab
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizGenerationScreen(
              subjectId: widget.subject.id,
              subjectName: widget.subject.name,
              subjectColor: subjectColor,
              storeName: _storeName,
            ),
          ),
        );
        _loadSubjectData();
        break;
      case 3: // Flashcards tab
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashcardGenerationScreen(
              subjectId: widget.subject.id,
              subjectName: widget.subject.name,
              subjectColor: subjectColor,
              storeName: _storeName,
            ),
          ),
        );
        _loadSubjectData();
        break;
      default:
        _openVoiceTutor();
    }
  }

  Widget _buildHeader(BuildContext context, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.inkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _showOptionsMenu(context),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.book_rounded, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (widget.subject.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subject.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                        Text(
                          '${widget.subject.progressPercentage.toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: widget.subject.progressPercentage / 100,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.inkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        padding: EdgeInsets.zero,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Notes'),
          Tab(text: 'Learn'),
          Tab(text: 'Quiz'),
          Tab(text: 'Cards'),
          Tab(text: 'Voice'),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
    required Color color,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: color.withOpacity(0.4),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.inkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.blue, size: 22),
                ),
                title: const Text('Edit Subject',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditSubjectDialog(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.red, size: 22),
                ),
                title: const Text('Delete Subject',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSubject(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditSubjectDialog(BuildContext context) async {
    final nameController = TextEditingController(text: widget.subject.name);
    final descriptionController =
        TextEditingController(text: widget.subject.description ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.inkSurface : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Edit Subject',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Subject Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                widget.subject.name = nameController.text.trim();
                widget.subject.description =
                    descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim();

                final subjectProvider =
                    Provider.of<SubjectProvider>(context, listen: false);
                await subjectProvider.updateSubject(widget.subject);

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSubject(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
            'Are you sure you want to delete "${widget.subject.name}"? This will also delete all its notes, quizzes and flashcards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final subjectProvider =
          Provider.of<SubjectProvider>(context, listen: false);
      await subjectProvider.deleteSubject(widget.subject.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildNotesView(bool isDark, Color subjectColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _uploadedFiles.length,
      itemBuilder: (context, index) {
        final fileName = _uploadedFiles[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.picture_as_pdf, color: subjectColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatButton(bool isDark, Color subjectColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    subjectColor.withOpacity(0.15),
                    subjectColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 64, color: subjectColor),
            ),
            const SizedBox(height: 32),
            Text(
              'Chat with AI Tutor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask questions about your uploaded materials',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubjectChatScreen(
                      subjectId: widget.subject.id,
                      subjectName: widget.subject.name,
                      subjectColor: subjectColor,
                      storeName: _storeName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Start Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: subjectColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizList(bool isDark, Color subjectColor) {
    return Column(
      children: [
        // Generate New Quiz Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizGenerationScreen(
                      subjectId: widget.subject.id,
                      subjectName: widget.subject.name,
                      subjectColor: subjectColor,
                      storeName: _storeName,
                    ),
                  ),
                );
                // Reload data after returning
                _loadSubjectData();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Generate New Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: subjectColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        // Quiz List
        Expanded(
          child: _quizzes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No quizzes yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate your first quiz above!',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = _quizzes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.inkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: subjectColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.quiz, color: subjectColor),
                        ),
                        title: Text(
                          quiz.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${quiz.questions.length} questions • ${quiz.isCompleted ? "Score: ${quiz.score}%" : "Not completed"}',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        trailing: Icon(
                          quiz.isCompleted
                              ? Icons.check_circle
                              : Icons.play_circle_outline,
                          color: quiz.isCompleted ? Colors.green : subjectColor,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                quiz: quiz,
                                onQuizCompleted: () {
                                  _loadSubjectData();
                                },
                              ),
                            ),
                          );
                          _loadSubjectData();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFlashcardList(bool isDark, Color subjectColor) {
    return Column(
      children: [
        // Generate New Flashcards Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FlashcardGenerationScreen(
                      subjectId: widget.subject.id,
                      subjectName: widget.subject.name,
                      subjectColor: subjectColor,
                      storeName: _storeName,
                    ),
                  ),
                );
                // Reload data after returning
                _loadSubjectData();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Generate New Flashcards'),
              style: ElevatedButton.styleFrom(
                backgroundColor: subjectColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        // Flashcard Decks List
        Expanded(
          child: _flashcards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.style_outlined,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No flashcards yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate your first deck above!',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _flashcards.length,
                  itemBuilder: (context, index) {
                    final deck = _flashcards[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.inkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: subjectColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.style, color: subjectColor),
                        ),
                        title: Text(
                          deck.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${deck.cards.length} cards • ${deck.masteryPercentage.toInt()}% mastered',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: subjectColor,
                          size: 16,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardScreen(deck: deck),
                            ),
                          );
                          _loadSubjectData();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
