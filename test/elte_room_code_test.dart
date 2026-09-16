import 'package:flutter_test/flutter_test.dart';
import 'package:neptun2/Misc/elte_room_code.dart';

void main() {
  group('ElteRoomCode maps deep-link', () {
    test('LD/LE/LK expose Lágymányos building queries', () {
      expect(
        ElteRoomCode.tryParse('LD-0-805')!.mapsSearchQuery(),
        'ELTE Déli Tömb, 1117 Budapest',
      );
      expect(
        ElteRoomCode.tryParse('LE-1-123')!.mapsSearchQuery(),
        'ELTE Északi Tömb, 1117 Budapest',
      );
      expect(
        ElteRoomCode.tryParse('LK-0-1')!.mapsSearchQuery(),
        'ELTE Kémiai tömb, 1117 Budapest',
      );
      expect(ElteRoomCode.tryParse('LD-0-805')!.hasMapsDeepLink, isTrue);
    });

    test('unknown prefix stays text-only (no maps query)', () {
      final parsed = ElteRoomCode.tryParse('XY-1-1')!;
      expect(parsed.hasMapsDeepLink, isFalse);
      expect(parsed.mapsSearchQuery(), isNull);
      expect(parsed.mapsUri(), isNull);
      expect(parsed.mapsUriFallbacks(), isEmpty);
    });

    test('LÉ normalizes to LE for maps', () {
      final parsed = ElteRoomCode.tryParse('LÉ-2-10')!;
      expect(parsed.hasMapsDeepLink, isTrue);
      expect(parsed.mapsSearchQuery(), 'ELTE Északi Tömb, 1117 Budapest');
    });

    test('mapsUriFallbacks always includes Google Maps https', () {
      final parsed = ElteRoomCode.tryParse('LD-0-805')!;
      final uris = parsed.mapsUriFallbacks();
      expect(uris, isNotEmpty);
      expect(
        uris.any((u) =>
            u.host.contains('google.com') && u.path.contains('maps')),
        isTrue,
      );
      // Primary URI is platform-specific (maps: on iOS/macOS VM may be false
      // in flutter_test — still must be non-null on whatever host runs tests).
      expect(parsed.mapsUri(), isNotNull);
    });
  });
}
