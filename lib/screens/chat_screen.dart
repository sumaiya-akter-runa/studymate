import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'chat_history_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  dynamic _conversationId;
  bool _isLoading = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _lastRecognizedWords = ''; 

  /// A big pool of useful student questions. Four random ones are shown each
  /// time a chat starts, so the screen never looks the same twice.
  static const _starterPool = [
    'Make me a 7-day exam study plan',
    'How do I stop procrastinating?',
    'Explain the Pomodoro technique',
    'Tips to remember what I read',
    'How to prepare for an exam in 3 days?',
    "Explain Newton's laws with examples",
    'Mean, median and mode: what is the difference?',
    'How do I write a strong essay intro?',
    'What caused World War I?',
    'Help me understand percentages',
    'How does the internet work?',
    'How can I focus better while studying?',
    'Explain supply and demand simply',
    'What is the best way to take notes?',
    'How do I solve quadratic equations?',
    'What are active recall and spaced repetition?',
    'How can I improve my English vocabulary?',
    'DNA vs RNA: what is the difference?',
    'How do I manage exam stress?',
    'Explain recursion in programming',
    'Quiz me on basic algebra',
    'What does GDP mean?',
    'How do I read a textbook faster?',
    'Explain how vaccines work',
    'How do I write a good conclusion?',
    'What is the difference between weather and climate?',
  ];
  static const _followUps = [
    'Explain further',
    'Give an example',
    'Summarize',
    'Quiz me on this',
  ];

  late List<String> _starters = _pickStarters();

  List<String> _pickStarters() {
    final list = List<String>.of(_starterPool)..shuffle(Random());
    return list.take(4).toList();
  }

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _isListening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice input error: ${error.errorMsg}')),
          );
        },
      );
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      if (mounted) setState(() {});
    } catch (e) {
      _speechAvailable = false;
    }
  }

  Future<void> _toggleListening() async {
    if (_isLoading) return;
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      await _initializeVoice();
      if (!_speechAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition is unavailable. Check Google app and microphone permission.')),
        );
        return;
      }
    }
    _lastRecognizedWords = '';
    try {
      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          if (mounted) {
            setState(() => _controller.text = _lastRecognizedWords);
            _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      );
      if (mounted) setState(() => _isListening = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start microphone: $e')),
      );
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      final isBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(text);
      await _tts.setLanguage(isBangla ? 'bn-BD' : 'en-US');
      await _tts.speak(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text-to-speech error: $e. Check installed voice data.')),
      );
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _conversationId = null;
      _starters = _pickStarters();
    });
  }

  Future<void> _openHistory() async {
    if (_isLoading) return;
    final id = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
    );
    if (id == null || !mounted) return;
    await _loadConversation(id);
  }

  Future<void> _loadConversation(dynamic id) async {
    setState(() => _isLoading = true);
    try {
      final d = await api.get('/api/chat/conversations/$id');
      final raw = d is Map ? listOf(d['messages']) : <dynamic>[];
      final loaded = <Map<String, String>>[];
      for (final m in raw) {
        final text = pickStr(m, ['content', 'text', 'message']);
        if (text.isEmpty) continue;
        final role = pickStr(m, ['role']) == 'user' ? 'user' : 'ai';
        loaded.add({'role': role, 'text': text});
      }
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
        _conversationId = id;
      });
      _scrollDown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Copied'),
        duration: Duration(seconds: 1),
      ));
  }

  /// Removes the last answer (or error) and asks the same question again.
  Future<void> _regenerate() async {
    if (_isLoading) return;
    final idx = _messages.lastIndexWhere((m) => m['role'] == 'user');
    if (idx == -1) return;
    final text = _messages[idx]['text']!;
    setState(() => _messages.removeRange(idx, _messages.length));
    await _send(text);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollDown();

    try {
      final body = <String, dynamic>{'message': text};
      if (_conversationId != null) body['conversation_id'] = _conversationId;
      final res = await api.post('/api/chat/', body: body);

      String reply = 'No response';
      if (res is Map) {
        final r = res['reply'];
        if (r is Map && r['content'] != null) {
          reply = r['content'].toString();
        } else if (r is String) {
          reply = r;
        } else {
          reply = pickStr(res, ['response', 'message', 'answer'], 'No response');
        }
        if (res['conversation_id'] != null) {
          _conversationId = res['conversation_id'];
        }
      }
      if (!mounted) return;
      setState(() => _messages.add({'role': 'ai', 'text': reply}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add({'role': 'error', 'text': friendlyError(e)}));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUserMsg = _messages.any((m) => m['role'] == 'user');
    final lastIsAi = _messages.isNotEmpty && _messages.last['role'] == 'ai';

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 10, 8, 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(bottom: BorderSide(color: context.hairline)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('StudyMate AI Tutor',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Ready to help you learn',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chat history',
                onPressed: _openHistory,
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: 'New chat',
                onPressed: _newChat,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              _bubble(
                'ai',
                "Hello! I'm StudyMate AI, your personal tutor. "
                    "Ask me anything about your studies.",
              ),
              if (!hasUserMsg)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _starters.length; i++)
                      FadeSlideIn(
                        key: ValueKey(_starters[i]),
                        delay: Duration(milliseconds: 150 + 80 * i),
                        child: ActionChip(
                          label: Text(_starters[i]),
                          onPressed: () => _send(_starters[i]),
                        ),
                      ),
                  ],
                ),
              ...List.generate(_messages.length, (i) {
                final m = _messages[i];
                final isLast = i == _messages.length - 1;
                return FadeSlideIn(
                  key: ValueKey('msg_$i'),
                  offset: 12,
                  duration: const Duration(milliseconds: 320),
                  child: _bubble(m['role']!, m['text']!,
                      actions: m['role'] == 'ai', isLast: isLast),
                );
              }),
              if (_isLoading) _typing(),
              if (hasUserMsg && lastIsAi && !_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < _followUps.length; i++)
                        FadeSlideIn(
                          delay: Duration(milliseconds: 60 * i),
                          offset: 8,
                          child: ActionChip(
                            label: Text(_followUps[i]),
                            onPressed: () => _send(_followUps[i]),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(top: BorderSide(color: context.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask me anything...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _isListening ? 'Stop voice input' : 'Speak',
                onPressed: _isLoading ? null : _toggleListening,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isLoading ? context.borderColor : AppColors.primary,
                ),
                child: IconButton(
                  onPressed: _isLoading ? null : () => _send(),
                  icon: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(String role, String text,
      {bool actions = false, bool isLast = false}) {
    final isUser = role == 'user';
    final isError = role == 'error';
    final isAi = role == 'ai';
    final bg = isUser
        ? AppColors.primary
        : isError
        ? AppColors.danger.withValues(alpha: 0.1)
        : context.surfaceColor;
    final fg = isUser
        ? Colors.white
        : isError
        ? AppColors.danger
        : context.textColor;
    final maxWidth = MediaQuery.of(context).size.width * (isAi ? 0.9 : 0.8);

    final Widget content = isAi
        ? MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: _markdownStyle(),
      builders: {'pre': _CodeBlockBuilder()},
    )
        : SelectableText(text,
        style: TextStyle(color: fg, fontSize: 15, height: 1.4));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: (isUser || isError) ? null : context.softShadow,
            ),
            child: content,
          ),
          if (actions)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniAction(Icons.copy_rounded, 'Copy', () => _copy(text)),
                _miniAction(Icons.volume_up_rounded, 'Read aloud', () => _speak(text)),
                if (isLast && !_isLoading)
                  _miniAction(Icons.refresh_rounded, 'Regenerate', _regenerate),
              ],
            ),
          if (isError && isLast && !_isLoading)
            TextButton.icon(
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
        ],
      ),
    );
  }

  Widget _miniAction(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: AppColors.muted,
      icon: Icon(icon),
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    final fg = context.textColor;
    final codeBg = context.isDark
        ? const Color(0xFF12151F)
        : const Color(0xFFF1F3F9);
    final body = TextStyle(color: fg, fontSize: 15, height: 1.4);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      listBullet: body,
      strong: body.copyWith(fontWeight: FontWeight.bold),
      em: body.copyWith(fontStyle: FontStyle.italic),
      h1: body.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      h2: body.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      h3: body.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
      a: body.copyWith(color: AppColors.primary),
      code: TextStyle(
        color: fg,
        fontFamily: 'monospace',
        fontSize: 13.5,
        backgroundColor: codeBg,
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      blockquoteDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      tableBorder: TableBorder.all(color: context.borderColor),
    );
  }

  Widget _typing() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: context.softShadow,
        ),
        child: const _TypingDots(),
      ),
    );
  }
}

/// Draws ``` code blocks with a language label and a Copy button.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
      BuildContext context,
      md.Element element,
      TextStyle? preferredStyle,
      TextStyle? parentStyle,
      ) {
    final code = element.textContent.trimRight();
    var language = '';
    final kids = element.children;
    if (kids != null && kids.isNotEmpty && kids.first is md.Element) {
      final cls = (kids.first as md.Element).attributes['class'];
      if (cls != null && cls.startsWith('language-')) {
        language = cls.substring('language-'.length);
      }
    }
    return _CodeBlock(code: code, language: language);
  }
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code, required this.language});
  final String code;
  final String language;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final fg = context.textColor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: fg.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.language.isEmpty ? 'code' : widget.language,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.muted,
                  ),
                  icon: Icon(_copied ? Icons.check : Icons.copy_rounded,
                      size: 16),
                  label: Text(_copied ? 'Copied' : 'Copy',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: TextStyle(
                  color: fg,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three bouncing dots shown while the AI is thinking.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is a little behind the one before it.
            final t = ((_c.value - i * 0.18) % 1.0);
            final bounce = t < 0.5 ? (t / 0.5) : (1 - (t - 0.5) / 0.5);
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
              width: 8,
              height: 8,
              transform: Matrix4.translationValues(0, -4 * bounce, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary
                    .withValues(alpha: 0.35 + 0.55 * bounce),
              ),
            );
          }),
        );
      },
    );
  }
}
