import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/openai_config_service.dart';
import '../../services/openai_rag_service.dart';
import '../../utils/app_theme.dart';

/// Lets the user paste in their own OpenAI API key. The key is stored only
/// on-device (SharedPreferences) and is never hardcoded in source — every
/// AI feature (PDF chat, quiz/flashcard generation) reads it from here.
class OpenAIApiKeyScreen extends StatefulWidget {
  const OpenAIApiKeyScreen({super.key});

  @override
  State<OpenAIApiKeyScreen> createState() => _OpenAIApiKeyScreenState();
}

class _OpenAIApiKeyScreenState extends State<OpenAIApiKeyScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hadExistingKey = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await OpenAIConfigService.getApiKey();
    if (!mounted) return;
    setState(() {
      if (key != null) {
        _controller.text = key;
        _hadExistingKey = true;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _errorText = 'Please enter an API key');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    // Verify the key actually works before saving it, so a typo or a
    // revoked/wrong key is caught right here instead of failing silently
    // later on some other screen.
    final validationError = await OpenAIRagService.validateKey(key);
    if (!mounted) return;

    if (validationError != null) {
      setState(() {
        _isSaving = false;
        _errorText = validationError;
      });
      return;
    }

    await OpenAIConfigService.setApiKey(key);
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context, true);
  }

  Future<void> _removeKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key'),
        content: const Text(
            'AI features (chat, quiz and flashcard generation) will stop working until you add a key again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await OpenAIConfigService.clearApiKey();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _openApiKeysPage() async {
    final uri = Uri.parse('https://platform.openai.com/api-keys');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('OpenAI API Key'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryAccent.withOpacity(0.15),
                          AppTheme.primaryAccent.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_rounded,
                            color: AppTheme.primaryAccent, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'AI chat, quiz and flashcard generation need your own OpenAI API key. It is stored only on this device and used only to call the OpenAI API directly.',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'API Key',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    onChanged: (_) {
                      if (_errorText != null) setState(() => _errorText = null);
                    },
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'sk-...',
                      filled: true,
                      fillColor: Theme.of(context).cardTheme.color,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      errorText: _errorText,
                      errorMaxLines: 3,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _openApiKeysPage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label:
                        const Text('Get an API key from platform.openai.com'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ),
                  if (_hadExistingKey) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _removeKey,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Remove Key'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
