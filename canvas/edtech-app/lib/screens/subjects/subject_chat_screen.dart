import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/openai_rag_service.dart';
import '../../services/openai_config_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../models/chat_message.dart' as model;
import '../settings/openai_api_key_screen.dart';

class SubjectChatScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final Color subjectColor;
  final String? storeName;

  const SubjectChatScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
    this.storeName,
  });

  @override
  State<SubjectChatScreen> createState() => _SubjectChatScreenState();
}

class _SubjectChatScreenState extends State<SubjectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<model.ChatMessage> _messages = [];
  final DatabaseService _dbService = DatabaseService();
  OpenAIRagService? _ragService;
  bool _isLoading = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initRagService();
    _loadChatHistory();
  }

  Future<void> _initRagService() async {
    final apiKey = await OpenAIConfigService.getApiKey();
    if (apiKey == null) return;

    final service = OpenAIRagService(apiKey);
    if (widget.storeName != null) {
      service.setStoreForSubject(widget.subjectId, widget.storeName!);
    }
    if (mounted) setState(() => _ragService = service);
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

  Future<void> _loadChatHistory() async {
    try {
      final messages =
          await _dbService.getChatMessagesForSubject(widget.subjectId);
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });

      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }

      // Scroll to bottom after loading
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    } catch (e) {
      print('Error loading chat history: $e');
      _addWelcomeMessage();
    }
  }

  Future<void> _addWelcomeMessage() async {
    final userId = SupabaseService.firebaseUserId ?? 'anonymous';
    final welcomeMessage = model.ChatMessage(
      id: _uuid.v4(),
      subjectId: widget.subjectId,
      userId: userId,
      message:
          'Hi! I\'m your AI tutor for ${widget.subjectName}. Ask me anything about your study materials!',
      isUser: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _messages.add(welcomeMessage);
    });

    await _dbService.saveChatMessage(welcomeMessage);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_ragService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add your OpenAI API key to chat with your AI tutor.'),
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

    final userId = SupabaseService.firebaseUserId ?? 'anonymous';

    // Add user message
    final userMessage = model.ChatMessage(
      id: _uuid.v4(),
      subjectId: widget.subjectId,
      userId: userId,
      message: text,
      isUser: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    await _dbService.saveChatMessage(userMessage);
    _messageController.clear();
    _scrollToBottom();

    // Get AI response
    try {
      final conversationHistory = _messages
          .map((m) =>
              {'role': m.isUser ? 'user' : 'assistant', 'content': m.message})
          .toList();

      final response = await _ragService!.chatWithSubject(
        subjectId: widget.subjectId,
        userMessage: text,
        conversationHistory: conversationHistory,
      );

      final aiMessage = model.ChatMessage(
        id: _uuid.v4(),
        subjectId: widget.subjectId,
        userId: userId,
        message: response,
        isUser: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });

      await _dbService.saveChatMessage(aiMessage);
      _scrollToBottom();

      if (mounted && response.toLowerCase().contains('api key')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your OpenAI API key looks invalid.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Update Key',
              textColor: Colors.white,
              onPressed: _promptForApiKey,
            ),
          ),
        );
      }
    } catch (e) {
      final errorMessage = model.ChatMessage(
        id: _uuid.v4(),
        subjectId: widget.subjectId,
        userId: userId,
        message: 'Sorry, I encountered an error. Please try again.',
        isUser: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });

      await _dbService.saveChatMessage(errorMessage);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChatHistory() async {
    await _dbService.deleteChatMessagesForSubject(widget.subjectId);
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Tutor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              widget.subjectName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: _clearChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, isDark);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.subjectColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(widget.subjectColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Thinking...',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(model.ChatMessage message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.subjectColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: widget.subjectColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser
                    ? widget.subjectColor
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.subjectColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: widget.subjectColor,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask a question...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.subjectColor,
                    widget.subjectColor.withOpacity(0.8),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.subjectColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
