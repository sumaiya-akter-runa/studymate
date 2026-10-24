import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Practice only the questions you got wrong.
/// This is practice only: nothing is saved to your quiz history or stats.
class RetryWrongScreen extends StatefulWidget {
  const RetryWrongScreen({super.key, required this.items});

  /// Items from the quiz result: question, options, correct_index, explanation.
  final List<dynamic> items;

  @override
  State<RetryWrongScreen> createState() => _RetryWrongScreenState();
}

class _RetryWrongScreenState extends State<RetryWrongScreen> {
  late List<dynamic> _round = List<dynamic>.of(widget.items);
  final List<dynamic> _missed = [];
  int _i = 0;
  int? _picked;
  int _fixed = 0;
  bool _finished = false;

  int? _correctOf(dynamic q) {
    final v = q is Map ? q['correct_index'] : null;
    return v is num ? v.toInt() : null;
  }

  void _pick(int k) {
    if (_picked != null) return;
    final q = _round[_i];
    final ok = k == _correctOf(q);
    setState(() {
      _picked = k;
      if (ok) {
        _fixed++;
      } else {
        _missed.add(q);
      }
    });
  }

  void _next() {
    if (_i < _round.length - 1) {
      setState(() {
        _i++;
        _picked = null;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  void _again() {
    setState(() {
      _round = List<dynamic>.of(_missed);
      _missed.clear();
      _i = 0;
      _picked = null;
      _fixed = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retry wrong answers')),
      body: _finished ? _summary() : _question(),
    );
  }

  Widget _summary() {
    final total = _round.length;
    final allFixed = _missed.isEmpty;
    final color = allFixed ? AppColors.accent : AppColors.warn;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Icon(allFixed ? Icons.emoji_events_outlined : Icons.trending_up,
              size: 72, color: color),
          const SizedBox(height: 16),
          Text(
            allFixed
                ? 'You got them all right!'
                : 'You fixed $_fixed of $total',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Practice only. This is not saved to your stats.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
          const Spacer(),
          if (!allFixed) ...[
            FilledButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.replay),
              label: Text(
                  'Practice ${_missed.length} more time${_missed.length == 1 ? '' : 's'}'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _question() {
    final q = _round[_i];
    final opts = optionsOf(q);
    final correct = _correctOf(q);
    final explanation = pickStr(q, ['explanation']);
    final answered = _picked != null;
    final isLast = _i == _round.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Question ${_i + 1} of ${_round.length}',
                style: const TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Text(pickStr(q, ['question', 'text']),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, height: 1.35)),
              ),
              const SizedBox(height: 16),
              for (var k = 0; k < opts.length; k++) _option(k, opts[k], correct),
              if (answered && explanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Why?',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(explanation, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: answered ? _next : null,
                child: Text(isLast ? 'Finish' : 'Next'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _option(int k, String text, int? correct) {
    final answered = _picked != null;
    final isCorrect = answered && k == correct;
    final isWrongPick = answered && k == _picked && k != correct;
    final Color accent = isCorrect
        ? AppColors.accent
        : isWrongPick
        ? AppColors.danger
        : context.borderColor;
    final highlighted = isCorrect || isWrongPick;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: highlighted
              ? accent.withValues(alpha: 0.12)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent, width: highlighted ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: answered ? null : () => _pick(k),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: highlighted ? accent : context.borderColor,
                  child: highlighted
                      ? Icon(isCorrect ? Icons.check : Icons.close,
                      size: 16, color: Colors.white)
                      : Text(
                    String.fromCharCode(65 + k),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textColor),
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