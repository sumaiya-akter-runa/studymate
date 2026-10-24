/// FILE: lib/services/document_service.dart
/// PURPOSE: PDF upload, status checks and "ask a question about this PDF".
///
/// How an upload works on the server (Step 6):
///   1. POST /api/documents/upload answers at once with status "processing".
///   2. A background worker reads the PDF. This takes from seconds to a few minutes.
///   3. GET /api/documents/<id> now shows status "ready" (or "failed" with error_message).
import 'api_client.dart';

class DocumentInfo {
  DocumentInfo.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = (json['title'] ?? '') as String,
        status = (json['status'] ?? '') as String,
        errorMessage = (json['error_message'] ?? '') as String,
        pageCount = (json['page_count'] ?? 0) as int,
        chunkCount = (json['chunk_count'] ?? 0) as int;

  final int id;
  final String title;
  final String status; // processing, ready or failed
  final String errorMessage;
  final int pageCount;
  final int chunkCount;

  bool get isReady => status == 'ready';
  bool get isFailed => status == 'failed';
}

class SourcePassage {
  SourcePassage({required this.page, required this.text});

  final int page;
  final String text;
}

class AskResult {
  AskResult({this.answer, this.notice, required this.sources});

  /// The written answer. It is null when the AI was unavailable; then [notice] explains and
  /// [sources] still holds the most relevant passages of the PDF.
  final String? answer;
  final String? notice;
  final List<SourcePassage> sources;
}

class DocumentService {
  DocumentService(this._api);

  final ApiClient _api;

  DocumentInfo _info(dynamic data) {
    try {
      return DocumentInfo.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException('The server sent a reply the app could not read.');
    }
  }

  Future<DocumentInfo> upload({required String path, required String name, String? title}) async {
    final data = await _api.postFile(
      '/api/documents/upload',
      filePath: path,
      fileName: name,
      fields: {'title': title ?? name},
    );
    return _info(data);
  }

  Future<DocumentInfo> get(int id) async => _info(await _api.get('/api/documents/$id'));

  Future<AskResult> ask(int id, String question) async {
    final data = await _api.post('/api/documents/$id/ask', body: {'question': question});
    try {
      final map = data as Map<String, dynamic>;
      final sources = (map['sources'] as List? ?? const []).map((item) {
        final m = item as Map<String, dynamic>;
        return SourcePassage(page: (m['page'] ?? 0) as int, text: (m['text'] ?? '') as String);
      }).toList();
      return AskResult(
        answer: map['answer'] as String?,
        notice: map['notice'] as String?,
        sources: sources,
      );
    } catch (_) {
      throw ApiException('The server sent a reply the app could not read.');
    }
  }
}
