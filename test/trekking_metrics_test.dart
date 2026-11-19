import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trek_maps/trekking_metrics.dart';

void main() {
  group('trek metrics', () {
    test('calculates route distance between recorded points', () {
      expect(calculateRouteDistance(const []), 0);

      final distance = calculateRouteDistance(const [
        LatLng(50.0755, 14.4378),
        LatLng(50.0765, 14.4378),
      ]);

      expect(distance, greaterThan(100));
      expect(distance, lessThan(120));
    });

    test('formats elapsed time and distance for the display', () {
      expect(formatElapsed(const Duration(seconds: 9)), '00:00:09');
      expect(
        formatElapsed(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '02:03:04',
      );
      expect(formatDistance(420), '420 m');
      expect(formatDistance(1250), '1.25 km');
    });
  });
}
