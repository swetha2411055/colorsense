import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chatbot_service.dart';
import '../models/scan_result.dart';
import '../providers/settings_provider.dart';
import '../core/theme.dart';
import 'dart:typed_data';

class ChatbotScreen extends StatefulWidget {
  final List<int>? initialImage;
  final List<DetectedColor>? initialColors;

  const ChatbotScreen({super.key, this.initialImage, this.initialColors});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ChatbotService _chatbot = ChatbotService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  List<int>? _pendingImage;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(
          'What colors are in this image? Please describe them for someone with ${_cvdName()} colorblindness.',
          imageBytes: widget.initialImage,
        );
      });
    }
  }

  String _cvdName() {
    final t = context.read<SettingsProvider>().cvdType;
    return t.name;
  }

  Future<void> _sendMessage(String text, {List<int>? imageBytes}) async {
    if (text.trim().isEmpty && imageBytes == null) return;
    _textCtrl.clear();
    final imgToSend = imageBytes ?? _pendingImage;
    setState(() { _isLoading = true; _pendingImage = null; });

    final settings = context.read<SettingsProvider>();
    await _chatbot.sendMessage(
      text,
      imageBytes: imgToSend,
      alreadyDetectedColors: widget.initialColors,
      cvdType: settings.cvdType.name,
    );

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _pendingImage = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildMessages()),
            if (_pendingImage != null) _buildImagePreview(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderColor))),
      child: Row(
        children: [
          Container(
            width: 38, height: 38, decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.accentCyan, Color(0xFFA78BFA)]),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Center(child: Text('🎨', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('ColorAI', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
              ]),
              Text('AI Color Assistant', style: TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () { _chatbot.clearHistory(); setState(() {}); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surface2Color, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text('Clear', style: TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    final messages = _chatbot.history;

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome message if empty
        if (messages.isEmpty)
          _buildBotBubble("Hi! I'm ColorAI. Upload a photo or ask me anything about colors — I'm here to help you see the world fully. 🌈"),

        ...messages.map((msg) {
          if (msg.role == 'user') return _buildUserBubble(msg.content, msg.imageBytes);
          return _buildBotBubble(msg.content);
        }),

        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36, decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accentCyan, Color(0xFFA78BFA)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(child: Text('🎨', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2Color, borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(children: [
                    _dot(0), const SizedBox(width: 4), _dot(1), const SizedBox(width: 4), _dot(2),
                  ]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delay * 200),
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentCyan, shape: BoxShape.circle)),
      ),
    );
  }

  Widget _buildBotBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.accentCyan, Color(0xFFA78BFA)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('🎨', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface2Color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text, List<int>? imageBytes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.accentCyan, Color(0xFF0084FF)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), bottomLeft: Radius.circular(16), topRight: Radius.circular(4), bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(Uint8List.fromList(imageBytes), height: 120, fit: BoxFit.cover),
                ),
                const SizedBox(height: 6),
              ],
              if (text.isNotEmpty)
                Text(text, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(Uint8List.fromList(_pendingImage!), height: 50, width: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          const Text('Image attached', style: TextStyle(fontSize: 11, color: AppTheme.accentCyan)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _pendingImage = null),
            child: const Text('✕', style: TextStyle(color: AppTheme.mutedColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderColor))),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 36, height: 36, decoration: BoxDecoration(
                color: AppTheme.surface2Color, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Center(child: Text('📎', style: TextStyle(fontSize: 16))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface2Color, borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask about any color...',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.mutedColor),
                  border: InputBorder.none,
                ),
                onSubmitted: (t) => _sendMessage(t),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_textCtrl.text),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppTheme.accentCyan, borderRadius: BorderRadius.circular(18)),
              child: const Center(child: Text('↑', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
    );
  }
}
