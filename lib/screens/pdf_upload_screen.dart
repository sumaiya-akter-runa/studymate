import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/api_client.dart' show ApiException;
import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Pick a PDF and upload it. Pops with `true` when the upload worked.
class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key});

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  PlatformFile? _file;
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    try {
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (!mounted || result.isEmpty) return;
      setState(() {
        _file = result.first;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not select the PDF: $e');
    }
  }

  /// File size read from disk (PlatformFile.size no longer exists in newer file_picker).
  int _fileBytes(PlatformFile f) {
    try {
      return f.path == null ? 0 : File(f.path!).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _upload() async {
    final f = _file;
    if (f == null || f.path == null) {
      setState(() => _error = 'Please choose a PDF first.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final file = File(f.path!);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('The selected PDF is empty or missing.');
      }

      // Cheap authenticated call: refreshes the access token if expired.
      await api.get('/api/auth/me');
      final token = await tokenStore.access;

      final title =
      f.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/documents/upload'),
      )
        ..fields['title'] = title
        ..files.add(await http.MultipartFile.fromPath('file', f.path!,
            filename: f.name));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final streamed =
      await request.send().timeout(const Duration(minutes: 5));
      final res = await http.Response.fromStream(streamed);

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {}

      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'Upload failed (HTTP ${res.statusCode}).';
        if (data is Map) {
          final m = data['error'] ?? data['detail'];
          if (m is String) {
            msg = m;
          } else if (data.isNotEmpty) {
            msg = data.entries.map((x) => '${x.key}: ${x.value}').join('\n');
          }
        }
        throw ApiException(msg, statusCode: res.statusCode);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload PDF')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(28),
            onTap: _uploading ? null : _pick,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_outlined,
                      size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text('Choose your PDF',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Tap here. Text-based PDFs work best (not scans).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          if (f != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf,
                      color: AppColors.danger, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        Text(_size(_fileBytes(f)),
                            style:
                            const TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                    _uploading ? null : () => setState(() => _file = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_uploading || f == null) ? null : _upload,
            icon: _uploading
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
            label: Text(_uploading ? 'Uploading...' : 'Upload PDF'),
          ),
        ],
      ),
    );
  }
}