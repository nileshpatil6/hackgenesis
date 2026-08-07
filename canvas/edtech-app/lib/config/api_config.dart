class ApiConfig {
  // The OpenAI API key used for AI chat/quiz/flashcard generation is NOT
  // stored here — it's entered by the user in-app (Profile > OpenAI API Key)
  // and read via OpenAIConfigService. See lib/services/openai_config_service.dart.
  static const String deepgramApiKey = 'YOUR_DEEPGRAM_API_KEY_HERE';
  static const String youtubeApiKey = 'YOUR_YOUTUBE_API_KEY_HERE';
  static const String deepgramBaseUrl = 'https://api.deepgram.com/v1';
  static const Map<String, String> freeTierLimits = {
    'deepgram': '45,000 minutes of audio per month (free tier)',
    'youtube': '10,000 units per day (free tier)',
  };
}
