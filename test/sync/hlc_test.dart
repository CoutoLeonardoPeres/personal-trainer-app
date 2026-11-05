import 'package:flutter_test/flutter_test.dart';

import 'package:app_personal/data/sync/hlc.dart';

void main() {
  const deviceId = '12345678-1234-1234-1234-123456789abc';

  test('gera HLC no formato aceito pelo backend', () {
    final clock = HybridLogicalClock(
      deviceId: deviceId,
      wallMs: 1_700_000_000_000,
    );

    final first = clock.tick(
      DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
    );
    final second = clock.tick(
      DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
    );

    expect(first, matches(RegExp(r'^\d{15}-[0-9a-f]{5}-[0-9a-f]{32}$')));
    expect(second.compareTo(first), greaterThan(0));
    expect(HybridLogicalClock.parse(second).node, deviceId.replaceAll('-', ''));
  });

  test('observa relógio remoto e mantém ordenação lógica', () {
    final clock = HybridLogicalClock(deviceId: deviceId, wallMs: 100);
    clock.observe(
      '000000000000200-0000a-12345678123412341234123456789abc',
      DateTime.fromMillisecondsSinceEpoch(100),
    );

    final local = clock.tick(DateTime.fromMillisecondsSinceEpoch(100));
    final parsed = HybridLogicalClock.parse(local);
    expect(parsed.wallMs, 200);
    expect(parsed.logical, greaterThan(10));
  });

  test('rejeita HLC malformado', () {
    expect(() => HybridLogicalClock.parse('invalid'), throwsFormatException);
  });
}
