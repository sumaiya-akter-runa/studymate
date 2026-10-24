import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'retry_wrong_screen.dart';

/// Take a quiz: one question at a time.
class QuizTakeScreen extends StatefulWidget {
  const QuizTakeScreen({super.key, required this.quiz});
  final Map quiz;

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  late final List<dynamic> _qs = listOf(widget.quiz['questions']);
  late final List<int?> _sel = List<int?>.filled(_qs.length, null);
  int _i = 0;
  bool _submitting = false;
  String? _error;

  bool get _allAnswered => !_sel.contains(null);

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final answers = <Map<String, dynamic>>[
        for (var k = 0; k < _qs.length; k++)
          {'question_id': _qs[k]['id'], 'selected_index': _sel[k] ?? 0},
      ];
      final r = await api.post('/api/quiz/${widget.quiz['id']}/submit',
          body: {'answers': answers});
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            result: r is Map ? r : const {},
            total: _qs.length,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = pickStr(widget.quiz, ['title'], 'Quiz');
    if (_qs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          icon: Icons.help_outline,
          title: 'No questions',
          message: 'This quiz has no questions.',
        ),
      );
    }

    final q = _qs[_i];
    final opts = optionsOf(q);
    final isLast = _i == _qs.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question ${_i + 1} of ${_qs.length}',
                    style: const TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: 0, end: (_i + 1) / _qs.length),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                      begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: ListView(
                key: ValueKey(_i),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Text(questionText(q),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.35)),
                  ),
                  const SizedBox(height: 16),
                  for (var k = 0; k < opts.length; k++) _option(k, opts[k]),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_i > 0)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _i--),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_i > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting || _sel[_i] == null
                          ? null
                          : isLast
                          ? (_allAnswered ? _submit : null)
                          : () => setState(() => _i++),
                      child: _submitting
                          ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                          : Text(isLast ? 'Submit' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(int k, String text) {
    final selected = _sel[_i] == k;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.10) : context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : context.borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _submitting ? null : () => setState(() => _sel[_i] = k),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor:
                  selected ? AppColors.primary : context.borderColor,
                  child: Text(
                    String.fromCharCode(65 + k),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : context.textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the score after submitting.
class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, required this.result, required this.total});
  final Map result;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = attemptPercent(result) ?? 0;
    final score = pickNum(result, ['score', 'correct', 'correct_count', 'correct_answers']);
    final tot = pickNum(result, ['total', 'total_questions', 'num_questions']) ?? total.toDouble();
    final attemptId = result['attempt_id'] ?? result['id'];
    final wrong = listOf(result['results'])
        .where((r) => r is Map && r['is_correct'] == false)
        .toList();

    String msg;
    Color color;
    if (pct >= 80) {
      msg = 'Excellent work!';
      color = AppColors.accent;
    } else if (pct >= 50) {
      msg = 'Good effort, keep practicing!';
      color = AppColors.warn;
    } else {
      msg = 'Keep going, you will get better!';
      color = AppColors.danger;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            ScoreRing(
              pct: pct,
              color: color,
              size: 170,
              stroke: 14,
              sub: (score != null && score <= tot)
                  ? '${score.round()} / ${tot.round()}'
                  : null,
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 700),
              child: Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            if (wrong.isNotEmpty) ...[
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RetryWrongScreen(items: wrong)),
                ),
                icon: const Icon(Icons.replay),
                label: Text(
                    'Retry ${wrong.length} wrong answer${wrong.length == 1 ? '' : 's'}'),
              ),
              const SizedBox(height: 12),
            ],
            if (attemptId != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => QuizReviewScreen(attemptId: attemptId)),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review answers'),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows every question with your answer and the correct one.
class QuizReviewScreen extends StatefulWidget {
  const QuizReviewScreen({super.key, required this.attemptId});
  final dynamic attemptId;

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await api.get('/api/quiz/attempts/${widget.attemptId}');
      dynamic raw = d;
      if (d is Map) {
        raw = d['answers'] ?? d['questions'] ?? d['results'] ?? d['review'];
      }
      if (!mounted) return;
      setState(() {
        _items = listOf(raw);
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

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: _error!, onRetry: _load));
    } else if (_items.isEmpty) {
      body = const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No review available',
        message: 'There are no answers to show for this attempt.',
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _items.length,
        itemBuilder: (context, i) => _card(i, _items[i]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review answers')),
      body: body,
    );
  }

  Widget _card(int i, dynamic a) {
    final q = (a is Map && a['question'] is Map) ? a['question'] : a;
    var text = questionText(q);
    if (text == 'Question' && a is Map) {
      text = pickStr(a, ['question_text', 'question'], 'Question');
    }
    final opts = optionsOf(q).isNotEmpty ? optionsOf(q) : optionsOf(a);
    final selected = pickNum(a, ['selected_index', 'selected', 'user_answer'])?.toInt();
    final correct = pickNum(q, ['correct_index', 'correct_answer', 'answer_index']) ??
        pickNum(a, ['correct_index', 'correct_answer', 'answer_index']);
    final correctIdx = correct?.toInt();
    final isCorrect = (a is Map && a['is_correct'] is bool)
        ? a['is_correct'] as bool
        : (selected != null && selected == correctIdx);
    final explanation = pickStr(a, ['explanation'], pickStr(q, ['explanation']));
    final color = isCorrect ? AppColors.accent : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: color),
                const SizedBox(width: 8),
                Text('Question ${i + 1}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, height: 1.35)),
            const SizedBox(height: 10),
            for (var k = 0; k < opts.length; k++)
              _reviewOption(k, opts[k], selected, correctIdx),
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(explanation, style: const TextStyle(height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewOption(int k, String text, int? selected, int? correct) {
    final isCorrect = k == correct;
    final isWrongPick = k == selected && k != correct;
    final color = isCorrect
        ? AppColors.accent
        : isWrongPick
        ? AppColors.danger
        : context.borderColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isCorrect || isWrongPick) ? color.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Text('${String.fromCharCode(65 + k)}.  ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
          if (isCorrect) const Icon(Icons.check, color: AppColors.accent, size: 18),
          if (isWrongPick) const Icon(Icons.close, color: AppColors.danger, size: 18),
        ],
      ),
    );
  }
}