import 'package:flutter/material.dart';

import '../services/api_client.dart' show ApiException;
import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'document_detail_screen.dart';
import 'pdf_upload_screen.dart';
import 'settings_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.onGoTo});
  final void Function(int) onGoTo;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _name = '';
  List<dynamic> _docs = [];
  List<dynamic> _quizzes = [];
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
    if (tabChanged.value == 0) _load();
  }

  Future<dynamic> _safe(Future<dynamic> f) async {
    try {
      return await f;
    } catch (e) {
      _error = friendlyError(e);
      if (e is ApiException && e.statusCode == 401) _expired = true;
      return null;
    }
  }

  bool _expired = false;

  Future<void> _load() async {
    _error = null;
    final r = await Future.wait([
      _safe(api.get('/api/auth/me')),
      _safe(api.get('/api/documents/')),
      _safe(api.get('/api/quiz/')),
      _safe(api.get('/api/quiz/attempts')),
    ]);
    if (!mounted) return;
    if (_expired) {
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
      return;
    }
    setState(() {
      final me = r[0];
      if (me is Map) {
        _name = pickStr(me, ['first_name']);
        if (_name.isEmpty) {
          _name = pickStr(me, ['email']).split('@').first;
        }
      }
      _docs = listOf(r[1]);
      _quizzes = listOf(r[2]);
      _attempts = listOf(r[3]);
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) _load(); // the name may have changed
  }

  Future<void> _logout() async {
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  double? get _avg {
    final vals = _attempts
        .map(attemptPercent)
        .whereType<double>()
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avg;
    final recent = _docs.take(4).toList();
    const sectionStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: _name.isEmpty ? _greeting : '$_greeting, $_name',
            subtitle: 'What would you like to study today?',
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) {
                if (v == 'settings') _openSettings();
                if (v == 'logout') _logout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'settings', child: Text('Settings')),
                PopupMenuItem(value: 'logout', child: Text('Log out')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null && !_loading) ...[
                  ErrorBanner(message: _error!, onRetry: _load),
                  const SizedBox(height: 16),
                ],
                FadeSlideIn(
                  child: StatStrip(items: [
                    StatItem(
                        icon: Icons.picture_as_pdf_outlined,
                        color: AppColors.danger,
                        value: _loading ? null : _docs.length,
                        label: 'PDFs'),
                    StatItem(
                        icon: Icons.quiz_outlined,
                        color: AppColors.primary,
                        value: _loading ? null : _quizzes.length,
                        label: 'Quizzes'),
                    StatItem(
                        icon: Icons.emoji_events_outlined,
                        color: AppColors.warn,
                        value: avg?.round(),
                        suffix: '%',
                        label: 'Avg score'),
                  ]),
                ),
                const SizedBox(height: 28),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 80),
                  child: Text('Quick actions', style: sectionStyle),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: Row(
                    children: [
                      Expanded(
                        child: QuickAction(
                          icon: Icons.smart_toy_outlined,
                          label: 'Ask AI',
                          color: AppColors.primary,
                          onTap: () => widget.onGoTo(1),
                        ),
                      ),
                      Expanded(
                        child: QuickAction(
                          icon: Icons.upload_file,
                          label: 'Upload',
                          color: AppColors.warn,
                          onTap: () async {
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PdfUploadScreen()),
                            );
                            if (ok == true) widget.onGoTo(2);
                          },
                        ),
                      ),
                      Expanded(
                        child: QuickAction(
                          icon: Icons.quiz_outlined,
                          label: 'Quiz',
                          color: AppColors.accent,
                          onTap: () => widget.onGoTo(3),
                        ),
                      ),
                      Expanded(
                        child: QuickAction(
                          icon: Icons.insights_outlined,
                          label: 'Progress',
                          color: AppColors.violet,
                          onTap: () => widget.onGoTo(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Recent PDFs', style: sectionStyle),
                      ),
                      TextButton(
                          onPressed: () => widget.onGoTo(2),
                          child: const Text('See all')),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _recentSection(recent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentSection(List<dynamic> recent) {
    if (_loading) {
      return const SkeletonPulse(
        key: ValueKey('loading'),
        child: ListGroup(children: [RowSkeleton(), RowSkeleton()]),
      );
    }
    if (recent.isEmpty) {
      return AppCard(
        key: const ValueKey('empty'),
        child: const Row(
          children: [
            Icon(Icons.upload_file_outlined, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                  'No PDFs yet. Upload one to ask questions and make quizzes.',
                  style: TextStyle(color: AppColors.muted, height: 1.35)),
            ),
          ],
        ),
      );
    }
    return FadeSlideIn(
      key: const ValueKey('list'),
      delay: const Duration(milliseconds: 240),
      child: ListGroup(
        children: recent.map((d) {
          return AppRow(
            leading: const IconBadge(
                icon: Icons.picture_as_pdf, color: AppColors.danger),
            title: pickStr(d, ['title'], 'Untitled PDF'),
            trailing: StatusChip(pickStr(d, ['status'])),
            onTap: () {
              if (pickStr(d, ['status']) == 'ready') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentDetailScreen(doc: d as Map)),
                );
              } else {
                widget.onGoTo(2);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}