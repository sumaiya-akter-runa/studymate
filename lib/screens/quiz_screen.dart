import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'quiz_take_screen.dart';

/// The "Quizzes" tab: all quizzes you generated. Tap one to take it.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic> _quizzes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    tabChanged.addListener(_onTab);
    _load();
  }

  @override
  void dispose() {
    tabChanged.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (tabChanged.value == 3) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final r = await api.get('/api/quiz/');
      if (!mounted) return;
      setState(() {
        _quizzes = listOf(r);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(dynamic quiz) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detail = await api.get('/api/quiz/${quiz['id']}');
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      if (detail is! Map) throw Exception('Unexpected response from server.');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizTakeScreen(quiz: detail)),
      );
      _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(dynamic quiz) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: const Text('This quiz will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await api.delete('/api/quiz/${quiz['id']}');
      _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GradientHeader(
          title: 'Quizzes',
          subtitle: 'Test yourself with AI made questions',
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _body(),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const ListSkeleton();
    if (_error != null && _quizzes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorBanner(message: _error!, onRetry: _load),
      );
    }
    if (_quizzes.isEmpty) {
      return const EmptyState(
        icon: Icons.quiz_outlined,
        title: 'No quizzes yet',
        message:
            'Open a PDF in the PDFs tab and tap "Generate quiz" to make one.',
      );
    }
    return RefreshIndicator(
      key: const ValueKey('quizzes'),
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListGroup(
            children: [
              for (var i = 0; i < _quizzes.length; i++)
                FadeSlideIn(
                  key: ValueKey('quiz_${pickStr(_quizzes[i], ['id'], '$i')}'),
                  delay: Duration(milliseconds: 45 * (i < 8 ? i : 8)),
                  child: _quizRow(_quizzes[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quizRow(dynamic q) {
    final count = q['question_count'] ??
        (q['questions'] is List ? (q['questions'] as List).length : null);
    final diff = pickStr(q, ['difficulty']);
    return AppRow(
      leading: const IconBadge(icon: Icons.quiz, color: AppColors.accent),
      title: pickStr(q, ['title'], 'Quiz #${q['id']}'),
      subtitle: Text(
        [
          if (count != null) '$count questions',
          if (diff.isNotEmpty) diff,
          shortDate(q['created_at']),
        ].where((s) => s.toString().isNotEmpty).join('  •  '),
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.muted),
        onPressed: () => _delete(q),
      ),
      onTap: () => _open(q),
    );
  }
}
