import 'package:flutter/foundation.dart';

import 'services/api_client.dart' show ApiException;

/// Tells the tabs which one was just opened, so they can refresh their data.
final ValueNotifier<int> tabChanged = ValueNotifier<int>(0);

/// Turns long server errors into one short sentence.
String friendlyError(Object e) {
  final raw = e is ApiException ? e.message : e.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('429') ||
      lower.contains('quota') ||
      lower.contains('rate limit') ||
      lower.contains('ai is busy')) {
    return 'The AI is busy right now. Please try again in a minute.';
  }
  if (lower.contains('model_not_found') || lower.contains('does not exist')) {
    return 'The AI model is not available. Please check GROQ_MODEL in the backend.';
  }
  var msg = raw.split('Details:').first.trim();
  if (msg.length > 220) msg = '${msg.substring(0, 220)}...';
  return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
}

/// Lists may come as [..] or as {"results": [..]} (paginated).
List<dynamic> listOf(dynamic r) {
  if (r is List) return r;
  if (r is Map && r['results'] is List) return r['results'] as List;
  return <dynamic>[];
}

String pickStr(dynamic m, List<String> keys, [String fallback = '']) {
  if (m is Map) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v is! Map && v is! List && v.toString().isNotEmpty) {
        return v.toString();
      }
    }
  }
  return fallback;
}

double? pickNum(dynamic m, List<String> keys) {
  if (m is Map) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v);
        if (p != null) return p;
      }
    }
  }
  return null;
}

/// Percentage 0-100 for an attempt / result map, or null if unknown.
double? attemptPercent(dynamic a) {
  final p = pickNum(a, ['percentage', 'percent', 'accuracy', 'score_percent']);
  if (p != null) return (p <= 1 ? p * 100 : p).clamp(0, 100).toDouble();
  final s = pickNum(a, ['score', 'correct', 'correct_count', 'correct_answers']);
  final t = pickNum(
      a, ['total', 'total_questions', 'num_questions', 'question_count']);
  if (s != null && t != null && t > 0) {
    return (s / t * 100).clamp(0, 100).toDouble();
  }
  return null;
}

String questionText(dynamic q) =>
    pickStr(q, ['text', 'question', 'question_text', 'prompt', 'title'], 'Question');

List<String> optionsOf(dynamic q) {
  final raw = (q is Map) ? (q['options'] ?? q['choices']) : null;
  if (raw is List) {
    return raw
        .map((o) => o is Map
            ? pickStr(o, ['text', 'label', 'option', 'value'])
            : o.toString())
        .toList();
  }
  return <String>[];
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String shortDate(dynamic v) {
  if (v == null) return '';
  final d = DateTime.tryParse(v.toString())?.toLocal();
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}
