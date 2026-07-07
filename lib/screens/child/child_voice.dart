import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/voice_service.dart';
import '../../services/backend_service.dart';
import '../../l10n.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime time;
  Message({required this.text, required this.isUser, required this.time});
}

class VoiceFlow extends StatefulWidget {
  const VoiceFlow({super.key});

  @override
  _VoiceFlowState createState() => _VoiceFlowState();
}

class _VoiceFlowState extends State<VoiceFlow> with SingleTickerProviderStateMixin {
  late StreamSubscription _commandSub;
  late StreamSubscription _textSub;
  late StreamSubscription _responseSub;

  List<Message> messages = [];
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animController;
  bool _isThinking = false;
  String currentLiveText = "";
  bool _alerting = false;
  bool _voiceReady = false;
  bool _pushToTalkActive = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initVoice();
  }

  Future<void> _initVoice() async {
    // Sync language from parent if linked
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('auth_id') ?? prefs.getString('child_id') ?? '';
    if (childId.isNotEmpty) {
      final parentLang = prefs.getString('child_language_$childId');
      if (parentLang != null) {
        await prefs.setString('language', parentLang);
        await prefs.setString('voice_language', parentLang == 'ar' ? 'ar-EG' : 'en-US');
        L10n.setLanguage(parentLang);
      }
    }
    await L10n.load();

    await VoiceService.instance.init();
    if (!_voiceReady) {
      _voiceReady = true;
      if (mounted) {
        await VoiceService.instance.speak(L10n.tr('voice_ready'));
        await VoiceService.instance.speak(L10n.tr('voice_safety_ready'));
      }
    }

    _textSub = VoiceService.instance.textStream.listen((text) {
      if (!mounted) return;
      if (text.trim().isEmpty) return;
      setState(() {
        currentLiveText = text;
        _isThinking = true;
      });

      final classification = IntentClassifier.classify(text);
      final intent = classification['intent'] as String;
      if (intent != 'none') {
        _addMessage(text, true);
        setState(() { currentLiveText = ""; _isThinking = false; });
        if (intent == 'object') {
          _handleObjectCommand(speakResponse: true);
        } else if (intent == 'scene') {
          _handleSceneCommand(speakResponse: true);
        }
      }
    });

    _responseSub = VoiceService.instance.responseStream.listen((response) {
      if (!mounted) return;
      if (response.trim().isEmpty) return;
      _addMessage(currentLiveText, true);
      _addMessage(response, false);
      setState(() {
        currentLiveText = "";
        _isThinking = false;
      });
      _scrollToBottom();
    });

    _commandSub = VoiceService.instance.commandStream.listen((command) async {
      if (!mounted) return;
      if (command.trim().isEmpty) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (command == "object") _handleObjectCommand(speakResponse: true);
      if (command == "scene") _handleSceneCommand(speakResponse: true);
    });

    // Push-to-talk mode: listening starts only while the user holds the button.
  }

  void _addMessage(String text, bool isUser) {
    if (text.isEmpty) return;
    setState(() {
      messages.add(Message(text: text, isUser: isUser, time: DateTime.now()));
    });
    _scrollToBottom();
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

  @override
  void dispose() {
    _commandSub.cancel();
    _textSub.cancel();
    _responseSub.cancel();
    _animController.dispose();
    _scrollController.dispose();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  // ====================== BUILD ======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment.center, radius: 1.5, colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),

              // Chat Area
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildChatBubble(messages[index]),
                ),
              ),

              // Live Preview / Thinking area
              if (_isThinking || currentLiveText.isNotEmpty)
                _buildLiveStatus(),

              // ===== Large Mode Selection Buttons =====
              _buildLargeButtons(),

              // Mic Visualizer Footer
              _buildFooter(),

              _buildPushToTalk(),
            ],
          ),
        ),
      ),
    );
  }

  // ===== LARGE ACCESSIBLE BUTTONS =====
  Widget _buildLargeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _handleObjectCommand(speakResponse: true),
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        L10n.tr('voice_object'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => _handleSceneCommand(speakResponse: true),
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        L10n.tr('voice_scene'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("BASERA AI", style: TextStyle(color: Colors.white54, letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 14)),
          Row(children: [
            IconButton(
              onPressed: _alerting ? null : _sendAlert,
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              tooltip: L10n.tr('voice_alert_parents'),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, "/child-profile"),
              icon: const Icon(Icons.person, color: Colors.white70, size: 26),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, "/child-qr"),
              icon: const Icon(Icons.qr_code_2, color: Colors.white70, size: 26),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, "/esp-camera"),
              icon: const Icon(Icons.videocam, color: Colors.greenAccent, size: 26),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Message msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF38BDF8).withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
            bottomRight: Radius.circular(msg.isUser ? 0 : 16),
          ),
          border: Border.all(color: msg.isUser ? const Color(0xFF38BDF8).withOpacity(0.3) : Colors.white10),
        ),
        child: Text(
          msg.text,
          style: TextStyle(color: msg.isUser ? const Color(0xFFBAE6FD) : Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildLiveStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _isThinking 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
            : const Icon(Icons.mic, color: Colors.redAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentLiveText.isEmpty ? L10n.tr('voice_listening') : currentLiveText,
              style: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut)),
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                _isThinking ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                _isThinking ? const Color(0xFFEF4444) : const Color(0xFF818CF8),
              ]),
              boxShadow: [BoxShadow(
                color: (_isThinking ? Colors.orange : Colors.blue).withOpacity(0.3),
                blurRadius: 30, spreadRadius: 5,
              )],
            ),
            child: Icon(_isThinking ? Icons.psychology : Icons.mic_rounded, size: 32, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildPushToTalk() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onLongPressStart: (_) async {
          if (_pushToTalkActive) return;
          setState(() => _pushToTalkActive = true);
          await VoiceService.instance.resumeListening();
        },
        onLongPressEnd: (_) async {
          if (!_pushToTalkActive) return;
          await VoiceService.instance.stopListening();
          if (mounted) {
            setState(() => _pushToTalkActive = false);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _pushToTalkActive ? const Color(0xFF2563EB) : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_pushToTalkActive ? Icons.mic : Icons.mic_none, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                _pushToTalkActive ? L10n.tr('voice_listening') : L10n.tr('voice_hold_speak'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== NAVIGATION ======================

  Future<void> _handleObjectCommand({bool speakResponse = false}) async {
    if (speakResponse) {
      final msg = L10n.tr('voice_opening_object');
      _addMessage(msg, false);
    }
    if (mounted) {
      Navigator.pushNamed(context, "/esp-camera");
    }
  }

  Future<void> _handleSceneCommand({bool speakResponse = false}) async {
    if (speakResponse) {
      final msg = L10n.tr('voice_opening_scene');
      _addMessage(msg, false);
    }
    if (mounted) {
      Navigator.pushNamed(context, "/esp-camera", arguments: {'mode': 'scene'});
    }
  }

  Future<void> _sendAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString('child_id') ??
        prefs.getString('linked_child_id') ??
        prefs.getString('auth_id') ??
        '';
    if (childId.isEmpty) return;

    setState(() => _alerting = true);
    final ok = await BackendService.instance.sendChildAlert(
      childId: childId,
      message: "Child pressed the alert button from the voice home screen.",
      type: "SOS",
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? L10n.tr('voice_alert_sent') : L10n.tr('voice_alert_failed')),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      setState(() => _alerting = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_voiceReady) {
      _voiceReady = true;
      VoiceService.instance.resumeListening();
    }
  }
}

class IntentClassifier {
  static const double threshold = 0.45;

  static const List<String> objectPhrases = [
    "عايز اعرف ايه اللي قدامي",
    "شوفلي الحاجات اللي موجوده",
    "عايز اعرف الاشياء",
    "اعمل object detection",
    "object",
    "objects",
    "what is in front of me",
    "detect objects",
    "tell me what you see",
    "الحاجات اللي حواليا",
    "عايز اعرف الحاجات اللي حواليا",
    "ايه ده",
    "ما هذا",
    "حاجات",
    "اشياء",
    "اوبجكت",
    "كشف الاشياء",
    "ايه اللي قدامي"
  ];

  static const List<String> scenePhrases = [
    "اوصف المكان",
    "قوللي المشهد",
    "عايز وصف للمكان",
    "اشرح اللي قدامي",
    "scene",
    "describe scene",
    "describe surroundings",
    "tell me about this place",
    "وصف المكان",
    "المشهد",
    "اوصفلي",
    "اشرحلي"
  ];

  static String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  static String _normalize(String text) {
    String res = text.toLowerCase();
    res = res.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ''); // remove punctuation
    res = _normalizeArabic(res);
    res = res.replaceAll(RegExp(r'\s+'), ' ');
    return res.trim();
  }

  static double _calculateSimilarity(String text, String target) {
    if (text == target) return 1.0;
    
    final textWords = text.split(' ').toSet();
    final targetWords = target.split(' ').toSet();
    
    if (targetWords.length == 1 && textWords.contains(targetWords.first)) {
      return 1.0;
    }
    
    if (text.contains(target)) {
      return target.length / text.length;
    }
    
    final intersection = textWords.intersection(targetWords).length;
    final union = textWords.union(targetWords).length;
    
    return union > 0 ? intersection / union : 0.0;
  }

  static Map<String, dynamic> classify(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return {'intent': 'none', 'confidence': 0.0};

    double maxObjectScore = 0.0;
    for (final phrase in objectPhrases) {
      final score = _calculateSimilarity(normalized, _normalize(phrase));
      if (score > maxObjectScore) maxObjectScore = score;
    }

    double maxSceneScore = 0.0;
    for (final phrase in scenePhrases) {
      final score = _calculateSimilarity(normalized, _normalize(phrase));
      if (score > maxSceneScore) maxSceneScore = score;
    }

    if (maxObjectScore > maxSceneScore && maxObjectScore >= threshold) {
      return {'intent': 'object', 'confidence': maxObjectScore};
    } else if (maxSceneScore > maxObjectScore && maxSceneScore >= threshold) {
      return {'intent': 'scene', 'confidence': maxSceneScore};
    }

    return {'intent': 'none', 'confidence': 0.0};
  }
}
