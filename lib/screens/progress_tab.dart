import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'quiz_take_screen.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  dynamic _perf;
  List<dynamic> _attempts = [];
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
    if (tabChanged.value == 4) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    String? err;
    dynamic perf;
    dynamic attempts;
    try {
      perf = await api.get('/api/quiz/performance');
    } catch (e) {
      err = friendlyError(e);
    }
    try {
      attempts = await api.get('/api/quiz/attempts');
    } catch (e) {
      err ??= friendlyError(e);
    }
    if (!mounted) return;
    setState(() {
      _perf = perf;
      _attempts = listOf(attempts);
      _error = (perf == null && _attempts.isEmpty) ? err : null;
      _loading = false;
    });
  }

  List<dynamic> _topics(String kind) {
    final p = _perf;
    if (p is Map) {
      for (final e in p.entries) {
        if (e.key.toString().toLowerCase().contains(kind) && e.value is List) {
          return e.value as List;
        }
      }
    }
    return [];
  }

  bool _practicing = false;

  Future<dynamic> _pickDocument(List<dynamic> docs) {
    return showModalBottomSheet<dynamic>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Practice from which PDF?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            for (final d in docs)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(pickStr(d, ['title'], 'PDF'),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _practiceWeak(List<dynamic> weak) async {
    if (_practicing) return;
    final names =
    weak.map(_topicName).where((t) => t.trim().isNotEmpty).toList();
    if (names.isEmpty) return;
    setState(() => _practicing = true);
    try {
      dynamic docId;
      var topics = names.take(5).toList();

      // The backend tells us which PDF each weak topic came from.
      final map = _perf is Map ? _perf['topic_documents'] : null;
      if (map is Map) {
        final groups = <dynamic, List<String>>{};
        for (final n in names) {
          final info = map[n.trim().toLowerCase()];
          if (info is Map && info['document_id'] != null) {
            groups.putIfAbsent(info['document_id'], () => []).add(n);
          }
        }
        if (groups.isNotEmpty) {
          // Practice the PDF that has the most weak topics.
          final best = groups.entries
              .reduce((a, b) => b.value.length > a.value.length ? b : a);
          docId = best.key;
          topics = best.value.take(5).toList();
        }
      }

      // Fallback: let the student choose a PDF.
      if (docId == null) {
        final r = await api.get('/api/documents/');
        final ready =
        listOf(r).where((d) => d is Map && d['status'] == 'ready').toList();
        if (!mounted) return;
        if (ready.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload a PDF first to practice.')));
          return;
        }
        final doc =
        ready.length == 1 ? ready.first : await _pickDocument(ready);
        if (doc == null || !mounted) return;
        docId = doc['id'];
      }

      final quiz = await api.post('/api/quiz/generate', body: {
        'document_id': docId,
        'num_questions': 5,
        'difficulty': 'medium',
        'focus_topics': topics,
      });
      if (!mounted) return;
      if (quiz is! Map) throw Exception('Unexpected response from server.');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizTakeScreen(quiz: quiz)),
      );
      if (mounted) _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _practicing = false);
    }
  }

  String _topicName(dynamic t) =>
      t is Map ? pickStr(t, ['topic', 'name', 'label', 'title'], 'Topic') : t.toString();

  double? _topicPercent(dynamic t) {
    final v = pickNum(t, [
      'accuracy', 'percentage', 'percent', 'score', 'correct_rate', 'success_rate'
    ]);
    if (v == null) return null;
    return (v <= 1 ? v * 100 : v).clamp(0, 100).toDouble();
  }

  double? get _overall {
    final p = _perf;
    if (p is Map) {
      final direct = pickNum(p, [
        'overall_accuracy', 'accuracy', 'average_score', 'average', 'overall'
      ]);
      if (direct != null) {
        return (direct <= 1 ? direct * 100 : direct).clamp(0, 100).toDouble();
      }
      if (p['overall'] is Map) {
        final o = attemptPercent(p['overall']);
        if (o != null) return o;
      }
    }
    final vals = _attempts.map(attemptPercent).whereType<double>().toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GradientHeader(
          title: 'Progress',
          subtitle: 'See how you are doing',
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
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorBanner(message: _error!, onRetry: _load),
      );
    }

    var weak = _topics('weak');
    var strong = _topics('strong');
    if (weak.isEmpty && strong.isEmpty && _perf is Map && _perf['topics'] is List) {
      for (final t in _perf['topics'] as List) {
        final p = _topicPercent(t);
        if (p != null && p < 60) {
          weak.add(t);
        } else {
          strong.add(t);
        }
      }
    }

    if (_attempts.isEmpty && weak.isEmpty && strong.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        title: 'No progress yet',
        message: 'Take a quiz and your results and weak topics will show here.',
      );
    }

    final overall = _overall;
    final lastScores = _attempts
        .take(7)
        .map(attemptPercent)
        .whereType<double>()
        .toList()
        .reversed
        .toList();

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Row(
              children: [
                ScoreRing(pct: overall, color: AppColors.accent),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overall score',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${_attempts.length} quiz attempts',
                          style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (lastScores.length >= 2) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent scores',
                      style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: lastScores.map((s) {
                        final c = s >= 70
                            ? AppColors.accent
                            : s >= 40
                            ? AppColors.warn
                            : AppColors.danger;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${s.round()}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: 0,
                                  end: (s / 100 * 90).clamp(4, 90).toDouble()),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (context, h, _) => Container(
                                width: 22,
                                height: h,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 16),
            _topicCard(
              'Focus on these topics',
              weak,
              AppColors.danger,
              Icons.trending_down,
              footer: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _practicing ? null : () => _practiceWeak(weak),
                  icon: _practicing
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fitness_center),
                  label: Text(_practicing
                      ? 'Generating (up to 20 sec)...'
                      : 'Practice these topics'),
                ),
              ),
            ),
          ],
          if (strong.isNotEmpty) ...[
            const SizedBox(height: 16),
            _topicCard('Your strong topics', strong, AppColors.accent,
                Icons.trending_up),
          ],
          if (_attempts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Quiz history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListGroup(children: _attempts.map(_attemptTile).toList(), indent: 72),
          ],
        ],
      ),
    );
  }

  Widget _topicCard(String title, List<dynamic> topics, Color color, IconData icon,
      {Widget? footer}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...topics.take(8).map((t) => PercentBar(
            label: _topicName(t),
            percent: _topicPercent(t),
            color: color,
          )),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _attemptTile(dynamic a) {
    final pct = attemptPercent(a);
    var title = pickStr(a, ['quiz_title', 'title']);
    if (title.isEmpty && a is Map && a['quiz'] is Map) {
      title = pickStr(a['quiz'], ['title']);
    }
    if (title.isEmpty) {
      title = 'Quiz #${a is Map ? (a['quiz'] ?? a['id'] ?? '') : ''}';
    }
    final color = pct == null
        ? AppColors.muted
        : pct >= 70
        ? AppColors.accent
        : pct >= 40
        ? AppColors.warn
        : AppColors.danger;
    final id = a is Map ? a['id'] : null;
    return AppRow(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Text(pct == null ? '--' : '${pct.round()}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ),
      title: title,
      subtitle: Text(
          shortDate(pickStr(a, ['created_at', 'submitted_at', 'completed_at'])),
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: id == null
          ? null
          : () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => QuizReviewScreen(attemptId: id)),
      ),
    );
  }
}