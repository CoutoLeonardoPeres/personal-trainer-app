import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;

/// Verificação leve antes do import manual (Android/iOS/desktop).
Future<bool> preflightSupabaseDnsLookup() async {
  try {
    final dns = await InternetAddress.lookup(
      'supabase.co',
    ).timeout(const Duration(seconds: 6));
    return dns.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } catch (_) {
    return true;
  }
}
