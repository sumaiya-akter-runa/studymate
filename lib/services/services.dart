/// FILE: lib/services/services.dart
/// PURPOSE: One shared copy of each service, so every screen uses the same ones.
/// (A simple approach that is easy to read. Larger apps use a state-management package.)
import 'api_client.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'document_service.dart';
import 'token_store.dart';

final tokenStore = TokenStore();
final api = ApiClient(tokenStore);
final auth = AuthService(api, tokenStore);
final chatService = ChatService(api);
final documentService = DocumentService(api);
