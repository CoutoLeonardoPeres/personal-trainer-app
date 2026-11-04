import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

/// Login com JWT por utilizador, necessário quando o Postgres usa RLS com
/// `auth.uid()`.
class SupabaseAuthService {
  SupabaseAuthService._();

  static SupabaseClient? get _client =>
      supabaseAppEnabled ? Supabase.instance.client : null;

  static User? get currentUser => _client?.auth.currentUser;

  static Session? get currentSession => _client?.auth.currentSession;

  static Stream<AuthState> get onAuthStateChange {
    final c = _client;
    if (c == null) return const Stream<AuthState>.empty();
    return c.auth.onAuthStateChange;
  }

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    return c.auth.signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> signInWithGoogle({
    String redirectTo = 'apppersonal://login-callback',
  }) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    await c.auth.signInWithOAuth(OAuthProvider.google, redirectTo: redirectTo);
  }

  static Future<void> signInWithGitHub({
    String redirectTo = 'apppersonal://login-callback',
  }) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    await c.auth.signInWithOAuth(OAuthProvider.github, redirectTo: redirectTo);
  }

  /// Finaliza o login OAuth via deep link (ex.: `apppersonal://login-callback#access_token=...`).
  static Future<void> handleAuthCallback(Uri uri) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    await c.auth.getSessionFromUrl(uri);
  }

  static Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    return c.auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> resetPasswordForEmail(String email) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    await c.auth.resetPasswordForEmail(email.trim());
  }

  /// Magic link seguro — convite ou reentrada sem gerar senha no app.
  static Future<void> signInWithOtp({
    required String email,
    String redirectTo = 'apppersonal://login-callback',
  }) async {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase não está inicializado.');
    }
    await c.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: redirectTo,
    );
  }
}
