import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncPushResult {
  const SyncPushResult({
    required this.results,
    required this.ackedThroughSeq,
    this.gap = false,
    this.expectedSeq,
  });

  final List<Map<String, dynamic>> results;
  final int ackedThroughSeq;
  final bool gap;
  final int? expectedSeq;

  bool get hasRejections =>
      results.any((result) => result['status'] == 'rejected');
}

class SyncPullResult {
  const SyncPullResult({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    required this.reset,
    required this.ackedThroughSeq,
  });

  final List<Map<String, dynamic>> changes;
  final int nextCursor;
  final bool hasMore;
  final bool reset;
  final int ackedThroughSeq;
}

class SyncSnapshotPage {
  const SyncSnapshotPage({
    required this.items,
    required this.snapshotSeq,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> items;
  final int snapshotSeq;
  final Map<String, dynamic>? nextCursor;
  final bool hasMore;
}

/// Cliente fino das RPCs do protocolo de sincronização.
///
/// Não acessa tabelas diretamente: toda mutação remota passa por `sync_push`.
class SupabaseSyncApi {
  SupabaseSyncApi(this._client);

  final SupabaseClient _client;

  Future<int> registerDevice({required String deviceId}) async {
    final result = await _client.rpc(
      'register_device',
      params: {
        'p_device_id': deviceId,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      },
    );
    return _asMap(result)['acked_through_seq'] as int? ?? 0;
  }

  Future<SyncPushResult> push({
    required String deviceId,
    required List<Map<String, dynamic>> operations,
  }) async {
    if (operations.isEmpty) {
      return const SyncPushResult(results: [], ackedThroughSeq: 0);
    }
    final result = _asMap(
      await _client.rpc(
        'sync_push',
        params: {'p_device_id': deviceId, 'p_ops': operations},
      ),
    );
    return SyncPushResult(
      results: _asList(result['results']),
      ackedThroughSeq: _asInt(result['acked_through_seq']),
      gap: result['gap'] == true,
      expectedSeq: result['expected_seq'] as int?,
    );
  }

  Future<SyncPullResult> pull({
    required String deviceId,
    required int since,
    int limit = 500,
  }) async {
    final result = _asMap(
      await _client.rpc(
        'sync_pull',
        params: {'p_device_id': deviceId, 'p_since': since, 'p_limit': limit},
      ),
    );
    return SyncPullResult(
      changes: _asList(result['changes']),
      nextCursor: _asInt(result['next_cursor'], fallback: since),
      hasMore: result['has_more'] == true,
      reset: result['reset'] == true,
      ackedThroughSeq: _asInt(result['acked_through_seq']),
    );
  }

  Future<SyncSnapshotPage> snapshot({
    Map<String, dynamic>? cursor,
    int limit = 500,
  }) async {
    final result = _asMap(
      await _client.rpc(
        'sync_snapshot',
        params: {'p_cursor': cursor ?? <String, dynamic>{}, 'p_limit': limit},
      ),
    );
    final next = result['next_cursor'];
    return SyncSnapshotPage(
      items: _asList(result['items']),
      snapshotSeq: _asInt(result['snapshot_seq']),
      nextCursor: next is Map ? Map<String, dynamic>.from(next) : null,
      hasMore: result['has_more'] == true,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Supabase sync RPC returned invalid JSON');
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}
