import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trek_maps/main.dart';

void main() {
  testWidgets('shows tracking controls and API key setup without a key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TrekMapsApp(apiKey: ''));

    expect(find.text('Trek Maps'), findsOneWidget);
    expect(find.text('Start tracking'), findsOneWidget);
    expect(find.textContaining('MAPY_API_KEY'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text('0 m'), findsOneWidget);
  });

  testWidgets('fits narrow portrait and landscape screens', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(320, 640), const Size(800, 360)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const TrekMapsApp(apiKey: ''));
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });
}
