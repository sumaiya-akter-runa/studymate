/// FILE: lib/screens/upload_screen.dart
/// PURPOSE: Choose a PDF, upload it to the backend, wait while the server prepares it,
///          then open a chat to ask questions about it.
///
/// Stages:  idle -> uploading -> processing -> ready (or failed)
///   uploading  : the file is travelling to the server
///   processing : the server's background worker reads the PDF (the app asks every 3 seconds)
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/document_service.dart';
import '../services/pdf_picker.dart';
import '../services/services.dart';
import 'chat_screen.dart';

enum _Stage { idle, uploading, processing, ready, failed }

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const _maxBytes = 10 * 1024 * 1024; // the server accepts PDFs up to 10 MB
  static const _pollEvery = Duration(seconds: 3);
  static const _giveUpAfter = Duration(minutes: 6);

  PickedPdf? _file;
  DocumentInfo? _doc;
  _Stage _stage = _Stage.idle;
  String? _error;

  bool get _busy => _stage == _Stage.uploading || _stage == _Stage.processing;

  String _size(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _choose() async {
    if (_busy) return;
    try {
      final picked = await pickPdf();
      if (picked == null || !mounted) return; // the user cancelled
      if (picked.sizeBytes > _maxBytes) {
        setState(() => _error = 'This PDF is larger than 10 MB. Please choose a smaller one.');
        return;
      }
      setState(() {
        _file = picked;
        _doc = null;
        _stage = _Stage.idle;
        _error = null;
      });
    } on PdfPickException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _clear() {
    if (_busy) return;
    setState(() {
      _file = null;
      _doc = null;
      _stage = _Stage.idle;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || _busy) return;

    setState(() {
      _stage = _Stage.uploading;
      _error = null;
    });

    try {
      final doc = await documentService.upload(path: file.path, name: file.name);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _stage = doc.isReady ? _Stage.ready : _Stage.processing;
      });
      if (!doc.isReady) await _waitUntilDone(doc.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e.message;
      });
    }
  }

  /// Asks the server every few seconds whether the PDF is ready.
  Future<void> _waitUntilDone(int id) async {
    final started = DateTime.now();
    while (mounted) {
      await Future.delayed(_pollEvery);
      if (!mounted) return;

      try {
        final doc = await documentService.get(id);
        if (!mounted) return;
        setState(() => _doc = doc);
        if (doc.isReady) {
          setState(() => _stage = _Stage.ready);
          return;
        }
        if (doc.isFailed) {
          setState(() {
            _stage = _Stage.failed;
            _error = doc.errorMessage.isEmpty ? 'The server could not process this PDF.' : doc.errorMessage;
          });
          return;
        }
      } on ApiException catch (e) {
        // A short network problem is fine: try again on the next round.
        // A rejected login or a missing document will not fix itself.
        if (e.statusCode == 401 || e.statusCode == 404) {
          if (!mounted) return;
          setState(() {
            _stage = _Stage.failed;
            _error = e.message;
          });
          return;
        }
      }

      if (DateTime.now().difference(started) > _giveUpAfter) {
        if (!mounted) return;
        setState(() {
          _stage = _Stage.failed;
          _error = 'This is taking too long. Please try again in a few minutes.';
        });
        return;
      }
    }
  }

  void _openChat() {
    final doc = _doc;
    if (doc == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(documentId: doc.id, documentTitle: doc.title)),
    );
  }

  String get _buttonLabel {
    switch (_stage) {
      case _Stage.uploading:
        return 'Uploading...';
      case _Stage.processing:
        return 'Processing...';
      case _Stage.ready:
        return 'Uploaded';
      case _Stage.failed:
        return 'Try again';
      case _Stage.idle:
        return 'Upload PDF';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _file != null && !_busy && _stage != _Stage.ready;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload PDF')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.picture_as_pdf, size: 72, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Upload Your Study Material',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a PDF document for your StudyMate learning workflow.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 24),
              _chooseCard(),
              if (_file != null) ...[
                const SizedBox(height: 16),
                _fileCard(_file!),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: canUpload ? _upload : null,
                icon: const Icon(Icons.upload_file),
                label: Text(_buttonLabel),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 16),
              _statusPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooseCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 56, color: Color(0xFF1E88E5)),
            const SizedBox(height: 12),
            const Text('Choose your PDF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Supported format: PDF (up to 10 MB)',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileCard(PickedPdf file) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.picture_as_pdf, size: 36, color: Colors.red.shade400),
        title: Text(
          file.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_size(file.sizeBytes)),
        trailing: IconButton(
          onPressed: _busy ? null : _clear,
          icon: const Icon(Icons.close),
          tooltip: 'Remove',
        ),
      ),
    );
  }

  Widget _panel({required Widget leading, required String text, required Color background, Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35, color: Colors.black87))),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }

  Widget _statusPanel() {
    const spinner = SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5));

    switch (_stage) {
      case _Stage.uploading:
        return _panel(
          leading: spinner,
          text: 'Uploading your PDF...',
          background: const Color(0xFFE8F0FE),
        );
      case _Stage.processing:
        return _panel(
          leading: spinner,
          text: 'Reading your PDF and preparing it for questions. This can take a minute.',
          background: const Color(0xFFE8F0FE),
        );
      case _Stage.ready:
        final doc = _doc;
        return _panel(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          text: doc == null
              ? 'Your PDF is ready.'
              : 'Your PDF is ready: ${doc.pageCount} pages, ${doc.chunkCount} passages prepared.',
          background: const Color(0xFFE6F4EA),
          action: FilledButton.tonalIcon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Ask questions about this PDF'),
          ),
        );
      case _Stage.failed:
      case _Stage.idle:
        final error = _error;
        if (error == null) return const SizedBox.shrink();
        return _panel(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          text: error,
          background: const Color(0xFFFDECEA),
        );
    }
  }
}
