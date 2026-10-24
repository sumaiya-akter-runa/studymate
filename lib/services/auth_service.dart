/// FILE: lib/services/auth_service.dart
/// PURPOSE: Register, log in, log out, and "who am I?".
import 'api_client.dart';
import 'token_store.dart';

class User {
  User.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        email = json['email'] as String,
        firstName = (json['first_name'] ?? '') as String;

  final int id;
  final String email;
  final String firstName;
}

class AuthService {
  AuthService(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<void> login(String email, String password) async {
    final data = await _api.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false, // we have no token yet
    );
    await _tokens.save(access: data['access'] as String, refresh: data['refresh'] as String);
  }

  Future<void> register(String email, String password, String firstName) async {
    await _api.post(
      '/api/auth/register',
      body: {'email': email, 'password': password, 'first_name': firstName},
      auth: false,
    );
    await login(email, password); // log in straight after registering
  }

  Future<User> me() async {
    final data = await _api.get('/api/auth/me');
    return User.fromJson(data as Map<String, dynamic>);
  }

  Future<bool> hasSession() async => (await _tokens.access) != null;

  Future<void> logout() => _tokens.clear();
}
