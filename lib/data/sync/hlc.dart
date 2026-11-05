import 'dart:math' as math;

/// Relógio lógico híbrido compatível com o formato validado pelo Supabase:
/// `000000000000000-00000-<device uuid sem hífens>`.
class HybridLogicalClock {
  HybridLogicalClock({required this.deviceId, int wallMs = 0, int logical = 0})
    : _wallMs = wallMs,
      _logical = logical;

  final String deviceId;
  int _wallMs;
  int _logical;

  int get wallMs => _wallMs;
  int get logical => _logical;

  String tick([DateTime? now]) {
    final physical = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    if (physical > _wallMs) {
      _wallMs = physical;
      _logical = 0;
    } else {
      _logical = (_logical + 1) & 0xfffff;
      if (_logical == 0) _wallMs++;
    }
    return _format();
  }

  void observe(String remoteHlc, [DateTime? now]) {
    final parsed = parse(remoteHlc);
    final physical = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final maxWall = math.max(math.max(_wallMs, parsed.wallMs), physical);
    if (maxWall == _wallMs && maxWall == parsed.wallMs && maxWall == physical) {
      _logical = math.max(_logical, parsed.logical) + 1;
    } else if (maxWall == _wallMs) {
      _logical++;
    } else if (maxWall == parsed.wallMs) {
      _logical = parsed.logical + 1;
    } else {
      _logical = 0;
    }
    _wallMs = maxWall;
    if (_logical > 0xfffff) {
      _wallMs++;
      _logical = 0;
    }
  }

  String _format() =>
      '${_wallMs.toString().padLeft(15, '0')}-'
      '${_logical.toRadixString(16).padLeft(5, '0')}-'
      '${deviceId.replaceAll('-', '').toLowerCase()}';

  static ParsedHlc parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3 ||
        parts[0].length != 15 ||
        parts[1].length != 5 ||
        parts[2].length != 32 ||
        int.tryParse(parts[0]) == null ||
        int.tryParse(parts[1], radix: 16) == null ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(parts[2])) {
      throw const FormatException('Invalid HLC');
    }
    return ParsedHlc(
      wallMs: int.parse(parts[0]),
      logical: int.parse(parts[1], radix: 16),
      node: parts[2],
    );
  }
}

class ParsedHlc {
  const ParsedHlc({
    required this.wallMs,
    required this.logical,
    required this.node,
  });

  final int wallMs;
  final int logical;
  final String node;
}
