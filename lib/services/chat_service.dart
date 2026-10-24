/// FILE: lib/services/chat_service.dart
/// PURPOSE: General AI chat (POST /api/chat/).
///
/// The server answers with JSON like:
///   {"conversation_id": 6, "reply": {"id": 12, "role": "assistant", "content": "Hello!", ...}}
/// The text to show on screen is reply.content. (Showing the whole response is the bug that
/// printed "{conversation_id: 6, reply: {...}}" in the chat bubble.)
import 'api_client.dart';

class ChatReply {
  ChatReply({required this.conversationId, required this.text});

  final int conversationId;
  final String text;
}

class ChatService {
  ChatService(this._api);

  final ApiClient _api;

  /// Pass the conversationId from the previous reply so the AI remembers the conversation.
  Future<ChatReply> send(String message, {int? conversationId}) async {
    final data = await _api.post(
      '/api/chat/',
      body: {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      },
    );
    try {
      final map = data as Map<String, dynamic>;
      final reply = map['reply'] as Map<String, dynamic>;
      return ChatReply(
        conversationId: map['conversation_id'] as int,
        text: (reply['content'] ?? '') as String,
      );
    } catch (_) {
      throw ApiException('The server sent a reply the app could not read.');
    }
  }
}
