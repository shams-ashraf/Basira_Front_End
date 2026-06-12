import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  // Free tier Gemini API key
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';

  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isReady = false;

  bool get isReady => _isReady && _apiKey != 'YOUR_GEMINI_API_KEY';

  Future<void> init() async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') return;

    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(
          '''You are Basera, a friendly AI for a blind child. 
Rules:
- Keep answers VERY SHORT (1 sentence).
- If the child wants to see, look, or identify objects/what is in front, reply EXACTLY: [ACTION:OBJECT]
- If the child wants a description of the place/scene, reply EXACTLY: [ACTION:SCENE]
- Otherwise, just be a warm friend.'''
        ),
      );
      _chat = _model!.startChat();
      _isReady = true;
    } catch (e) {
      debugPrint('ChatService init error: $e');
    }
  }

  Future<ChatResponse> sendMessage(String text) async {
    if (!_isReady) {
      final fallback = _fallback(text);
      return ChatResponse(text: fallback['text']!, action: fallback['action']);
    }

    try {
      final response = await _chat!.sendMessage(Content.text(text));
      final reply = response.text ?? "I'm here, tell me again.";

      if (reply.contains('[ACTION:OBJECT]')) return ChatResponse(text: "Looking for objects...", action: "object");
      if (reply.contains('[ACTION:SCENE]')) return ChatResponse(text: "Scanning the scene...", action: "scene");

      return ChatResponse(text: reply, action: null);
    } catch (e) {
      final fb = _fallback(text);
      return ChatResponse(text: fb['text']!, action: fb['action']);
    }
  }

  Map<String, String?> _fallback(String text) {
    final t = text.toLowerCase();
    
    // Robust local matching for blind child needs
    if (t.contains('object') || t.contains('what is this') || t.contains('what is that') || 
        t.contains('identify') || t.contains('look at') || t.contains('see') || 
        t.contains('detect') || t.contains('front of me')) {
      return {'text': "Checking for objects nearby.", 'action': "object"};
    }
    
    if (t.contains('scene') || t.contains('describe') || t.contains('where am i') || 
        t.contains('around') || t.contains('place') || t.contains('surroundings')) {
      return {'text': "Describing your surroundings.", 'action': "scene"};
    }

    if (t.contains('hello') || t.contains('hi') || t.contains('hey')) {
      return {'text': "Hi! I'm Basera. I'm ready to help you see the world.", 'action': null};
    }

    return {'text': "I'm listening. Ask me to look at something or describe the place.", 'action': null};
  }
}

class ChatResponse {
  final String text;
  final String? action;
  ChatResponse({required this.text, this.action});
}
