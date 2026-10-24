import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'quiz_take_screen.dart';

/// Ask questions about one PDF and generate a quiz from it.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key, required this.doc});
  final Map doc;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _question = TextEditingController();
  final List<Map<String, dynamic>> _qa = [];
  bool _asking = false;

  int _count = 5;
  String _difficulty = 'medium';
  bool _generating = false;
  String? _quizError;

  String _summary = '';
  bool _summarizing = false;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  /// Shows the summary saved earlier (if any) without calling the AI again.
  Future<void> _loadSummary() async {
    try {
      final d = await api.get('/api/documents/${widget.doc['id']}/summary');
      if (!mounted) return;
      if (d is Map && d['summary'] != null) {
        setState(() => _summary = d['summary'].toString());
      }
    } catch (_) {
      // Not important: the student can still tap "Summarize".
    }
  }

  Future<void> _summarize({bool regenerate = false}) async {
    setState(() {
      _summarizing = true;
      _summaryError = null;
    });
    try {
      final d = await api.post('/api/documents/${widget.doc['id']}/summary',
          body: {'regenerate': regenerate});
      if (!mounted) return;
      setState(() => _summary = d is Map ? pickStr(d, ['summary']) : '');
    } catch (e) {
      if (mounted) setState(() => _summaryError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  MarkdownStyleSheet _summaryStyle() {
    final body = TextStyle(color: context.textColor, fontSize: 15, height: 1.4);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      listBullet: body,
      strong: body.copyWith(fontWeight: FontWeight.bold),
      h2: body.copyWith(
          fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _question.text.trim();
    if (q.isEmpty || _asking) return;
    FocusScope.of(context).unfocus();
    setState(() => _asking = true);
    String answer;
    List<dynamic> sources = [];
    try {
      final data = await api
          .post('/api/documents/${widget.doc['id']}/ask', body: {'question': q});
      answer = 'No answer returned.';
      if (data is Map) {
        final a = data['answer'] ?? data['reply'] ?? data['response'];
        if (a is Map && a['content'] != null) {
          answer = a['content'].toString();
        } else if (a != null) {
          answer = a.toString();
        } else if (data['notice'] != null) {
          // The PDF did not contain enough information for this question.
          answer = data['notice'].toString();
        }
        sources = listOf(data['sources']);
      }
    } catch (e) {
      answer = friendlyError(e);
    }
    if (!mounted) return;
    setState(() {
      _qa.insert(0, {'q': q, 'a': answer, 'sources': sources});
      _question.clear();
      _asking = false;
    });
  }

  void _showSource(dynamic s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From page ${s['page'] ?? '?'}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(pickStr(s, ['text']),
                      style: const TextStyle(height: 1.45)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _quizError = null;
    });
    try {
      final quiz = await api.post('/api/quiz/generate', body: {
        'document_id': widget.doc['id'],
        'num_questions': _count,
        'difficulty': _difficulty,
      });
      if (!mounted) return;
      if (quiz is! Map) throw Exception('Unexpected response from server.');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizTakeScreen(quiz: quiz)),
      );
    } catch (e) {
      if (mounted) setState(() => _quizError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = pickStr(widget.doc, ['title'], 'PDF');
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary
          FadeSlideIn(child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, color: AppColors.warn),
                    SizedBox(width: 8),
                    Text('Summary & key points',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_summary.isEmpty) ...[
                  const Text(
                      'Get the big picture, the key points and the important terms of this PDF.',
                      style: TextStyle(color: AppColors.muted, height: 1.4)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _summarizing ? null : () => _summarize(),
                      icon: _summarizing
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_summarizing
                          ? 'Summarizing (up to 20 sec)...'
                          : 'Summarize this PDF'),
                    ),
                  ),
                ] else ...[
                  MarkdownBody(
                    data: _summary,
                    selectable: true,
                    styleSheet: _summaryStyle(),
                    inlineSyntaxes: [_PageTagSyntax()],
                    builders: {'pagetag': _PageTagBuilder()},
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                      _summarizing ? null : () => _summarize(regenerate: true),
                      icon: _summarizing
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_summarizing ? 'Writing...' : 'Regenerate'),
                    ),
                  ),
                ],
                if (_summaryError != null) ...[
                  const SizedBox(height: 8),
                  ErrorBanner(message: _summaryError!),
                ],
              ],
            ),
          )),
          const SizedBox(height: 16),
          // Ask
          FadeSlideIn(child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Ask about this PDF',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _question,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ask(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Summarize the main topic',
                    suffixIcon: IconButton(
                      onPressed: _asking ? null : _ask,
                      icon: _asking
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: AppColors.primary),
                    ),
                  ),
                ),
                if (_qa.isNotEmpty) const SizedBox(height: 12),
                ..._qa.map((m) => FadeSlideIn(
                  key: ValueKey('${m['q']}${m['a']}'),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.quietFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${m['q']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                        const SizedBox(height: 6),
                        SelectableText('${m['a']}',
                            style: const TextStyle(height: 1.4)),
                        Builder(builder: (context) {
                          final src = (m['sources'] as List? ?? const [])
                              .where((s) => s is Map)
                              .toList();
                          if (src.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('Sources:',
                                    style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12)),
                                for (final s in src)
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                        Icons.menu_book_outlined,
                                        size: 16),
                                    label: Text('Page ${s['page'] ?? '?'}'),
                                    onPressed: () => _showSource(s),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),
          // Quiz
          FadeSlideIn(delay: const Duration(milliseconds: 120), child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: AppColors.accent),
                    SizedBox(width: 8),
                    Text('Create a quiz',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Questions',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [5, 10, 15]
                      .map((n) => ChoiceChip(
                    label: Text('$n'),
                    selected: _count == n,
                    onSelected: _generating
                        ? null
                        : (_) => setState(() => _count = n),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Text('Difficulty',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['easy', 'medium', 'hard']
                      .map((d) => ChoiceChip(
                    label: Text(d[0].toUpperCase() + d.substring(1)),
                    selected: _difficulty == d,
                    onSelected: _generating
                        ? null
                        : (_) => setState(() => _difficulty = d),
                  ))
                      .toList(),
                ),
                if (_quizError != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _quizError!),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generating
                      ? 'Generating (up to 20 sec)...'
                      : 'Generate quiz'),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

/// Finds page references like "(page 4)" or "(pages 3-5)" in the summary.
class _PageTagSyntax extends md.InlineSyntax {
  _PageTagSyntax()
      : super(r'\([Pp]ages?\s*\d+(?:\s*(?:[-–,&]|and)\s*\d+)*\s*\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('pagetag', match[0]!));
    return true;
  }
}

/// Draws a page reference as a small bold purple tag, e.g. [page 4].
class _PageTagBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
      BuildContext context,
      md.Element element,
      TextStyle? preferredStyle,
      TextStyle? parentStyle,
      ) {
    final label = element.textContent.replaceAll(RegExp(r'^\(|\)$'), '');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: (preferredStyle ?? const TextStyle()).copyWith(
          color: AppColors.violet,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          height: 1.3,
        ),
      ),
    );
  }
}