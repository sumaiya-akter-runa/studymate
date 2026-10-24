import 'dart:async';

import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'document_detail_screen.dart';
import 'pdf_upload_screen.dart';

class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  List<dynamic> _docs = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    tabChanged.addListener(_onTab);
    _load();
  }

  @override
  void dispose() {
    tabChanged.removeListener(_onTab);
    _timer?.cancel();
    super.dispose();
  }

  void _onTab() {
    if (tabChanged.value == 2) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final r = await api.get('/api/documents/');
      if (!mounted) return;
      setState(() {
        _docs = listOf(r);
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
    _schedulePoll();
  }

  void _schedulePoll() {
    _timer?.cancel();
    final busy = _docs.any((d) {
      final s = pickStr(d, ['status']).toLowerCase();
      return s != 'ready' && s != 'failed';
    });
    if (busy && mounted) {
      _timer = Timer(const Duration(seconds: 4), () {
        if (mounted) _load(silent: true);
      });
    }
  }

  Future<void> _upload() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PdfUploadScreen()),
    );
    if (ok == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded! Processing your PDF...')),
      );
      _load();
    }
  }

  Future<void> _delete(dynamic d) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: Text(
            '"${pickStr(d, ['title'], 'This PDF')}" and its quizzes may be removed.'),
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
      await api.delete('/api/documents/${d['id']}');
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
        GradientHeader(
          title: 'My PDFs',
          subtitle: 'Upload study material and learn from it',
          trailing: IconButton.filled(
            style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary),
            onPressed: _upload,
            icon: const Icon(Icons.add),
            tooltip: 'Upload PDF',
          ),
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
    if (_error != null && _docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorBanner(message: _error!, onRetry: _load),
      );
    }
    if (_docs.isEmpty) {
      return EmptyState(
        icon: Icons.upload_file,
        title: 'No PDFs yet',
        message: 'Upload a PDF to ask questions and generate quizzes.',
        actionLabel: 'Upload PDF',
        onAction: _upload,
      );
    }
    return RefreshIndicator(
      key: const ValueKey('docs'),
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListGroup(
            children: [
              for (var i = 0; i < _docs.length; i++)
                FadeSlideIn(
                  key: ValueKey('doc_${pickStr(_docs[i], ['id'], '$i')}'),
                  delay: Duration(milliseconds: 45 * (i < 8 ? i : 8)),
                  child: _docRow(_docs[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _docRow(dynamic d) {
    final status = pickStr(d, ['status']);
    final ready = status.toLowerCase() == 'ready';
    final failed = status.toLowerCase() == 'failed';
    return AppRow(
      leading: const IconBadge(
          icon: Icons.picture_as_pdf, color: AppColors.danger),
      title: pickStr(d, ['title'], 'Untitled PDF'),
      subtitle: Row(
        children: [
          StatusChip(status),
          if (!ready && !failed) ...[
            const SizedBox(width: 8),
            const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
          const SizedBox(width: 8),
          Text(shortDate(d['created_at']),
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.muted),
        onPressed: () => _delete(d),
      ),
      onTap: () {
        if (ready) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(doc: d as Map)),
          );
        } else if (failed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(pickStr(d, ['error_message'],
                  'Processing failed. Please upload again.'))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Still processing, please wait...')));
        }
      },
    );
  }
}