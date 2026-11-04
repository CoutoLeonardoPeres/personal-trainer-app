import 'package:app_personal/data/sync/sync_watermark_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncWatermarkStore', () {
    test('persiste e recupera watermark', () async {
      final t = DateTime.utc(2026, 7, 9, 12, 0);
      await SyncWatermarkStore.setWatermark(
        table: 'day_workouts',
        at: t,
        scope: 'student:s1',
      );
      final read = await SyncWatermarkStore.getWatermark(
        table: 'day_workouts',
        scope: 'student:s1',
      );
      expect(read, t);
    });

    test('advanceWatermark não retrocede', () async {
      final early = DateTime.utc(2026, 1, 1);
      final later = DateTime.utc(2026, 6, 1);
      await SyncWatermarkStore.setWatermark(
        table: '_global',
        at: later,
        scope: 'admin',
      );
      await SyncWatermarkStore.advanceWatermark(
        table: '_global',
        candidate: early,
        scope: 'admin',
      );
      final cur = await SyncWatermarkStore.getWatermark(
        table: '_global',
        scope: 'admin',
      );
      expect(cur, later);
    });

    test('scopeForSession distingue perfis', () {
      expect(SyncWatermarkStore.scopeForSession(fullCloud: true), 'admin');
      expect(
        SyncWatermarkStore.scopeForSession(fullCloud: true, studentId: 's1'),
        'student:s1',
      );
      expect(
        SyncWatermarkStore.scopeForSession(personalId: 'p1'),
        'personal:p1',
      );
    });
  });
}
