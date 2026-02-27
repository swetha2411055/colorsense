import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/scan_result.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<int>? imageBytes; // For image messages

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.imageBytes,
  });
}

/// ChatbotService
/// Uses Claude API to answer color-related questions.
/// Sends image + detected color context with each message.
class ChatbotService {
  // Replace with your actual API key from https://console.anthropic.com
  static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-opus-4-6';

  final List<ChatMessage> _history = [];

  List<ChatMessage> get history => List.unmodifiable(_history);

  static const String _systemPrompt = '''
You are ColorAI, an empathetic and helpful AI assistant for people with color vision deficiencies (colorblindness).

Your role:
1. Help users understand colors in images they share
2. Describe how colors appear to people with different CVD types
3. Give practical advice (outfit matching, traffic lights, food freshness, etc.)
4. Explain what colors they might be confusing and why
5. Be encouraging and never make the user feel limited

When analyzing images:
- Identify dominant and accent colors precisely
- Mention hex codes and descriptive names
- Explain color relationships (complementary, warm/cool, etc.)
- Flag color-critical situations (e.g., traffic lights, warning signs)

Keep responses concise, warm, and practical.
''';

  Future<String> sendMessage(
    String userMessage, {
    List<int>? imageBytes,
    List<DetectedColor>? alreadyDetectedColors,
    String cvdType = 'Deuteranopia',
  }) async {
    // Build context string if colors already detected
    String contextStr = '';
    if (alreadyDetectedColors != null && alreadyDetectedColors.isNotEmpty) {
      final colorList = alreadyDetectedColors.map((c) =>
        '${c.name} (${c.hexCode}, ${(c.percentage * 100).toStringAsFixed(0)}%)'
      ).join(', ');
      contextStr = '\n\n[App context: Detected colors: $colorList. User CVD type: $cvdType]';
    }

    // Add to local history
    _history.add(ChatMessage(
      role: 'user',
      content: userMessage,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    ));

    // Build messages array for API
    final List<Map<String, dynamic>> messages = [];

    for (int i = 0; i < _history.length; i++) {
      final msg = _history[i];
      if (msg.imageBytes != null && msg.role == 'user') {
        // Include image as base64
        final base64Image = base64Encode(msg.imageBytes!);
        messages.add({
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {
              'type': 'text',
              'text': msg.content + (i == _history.length - 1 ? contextStr : ''),
            }
          ]
        });
      } else {
        messages.add({
          'role': msg.role,
          'content': msg.content + (i == _history.length - 1 && msg.role == 'user' ? contextStr : ''),
        });
      }
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'system': _systemPrompt,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantReply = data['content'][0]['text'] as String;

        _history.add(ChatMessage(
          role: 'assistant',
          content: assistantReply,
          timestamp: DateTime.now(),
        ));

        return assistantReply;
      } else {
        final errorMsg = 'API error: ${response.statusCode}';
        _history.add(ChatMessage(role: 'assistant', content: errorMsg, timestamp: DateTime.now()));
        return errorMsg;
      }
    } catch (e) {
      const errorMsg = 'Failed to connect. Please check your internet connection.';
      _history.add(ChatMessage(role: 'assistant', content: errorMsg, timestamp: DateTime.now()));
      return errorMsg;
    }
  }

  void clearHistory() => _history.clear();

  /// Generate a quick color summary without full conversation
  Future<String> describeColorForCvd(DetectedColor color, String cvdType) async {
    final prompt = 'In 1 short sentence, describe what "$cvdType" users might perceive when seeing ${color.name} (${color.hexCode}) and how to distinguish it.';
    return sendMessage(prompt);
  }
}
