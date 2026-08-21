import 'package:creathon/features/expo/expo_scene.dart';
import 'package:creathon/features/home/home_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// The four tabs share one shell with an indexed stack, so the risk worth
/// covering is not "does the tap work" but "does each tab keep its own state
/// while the others stay alive".
void main() {
  setUpAll(loadAppFonts);

  Future<FakeAuthRepository> onboard(WidgetTester tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      sessions: [
        testSession(
          id: 'e1',
          title: 'Yapay Zekâ ile Üretim',
          hour: 10,
          sectors: ['Yapay Zekâ'],
        ),
        testSession(
          id: 'e2',
          title: 'Uzay Ekonomisi',
          hour: 14,
          sectors: ['Havacılık & Uzay'],
        ),
      ],
    );
    await completeOnboarding(tester, auth: auth);
    return auth;
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await advance(tester, frames: 10);
  }

  testWidgets('every tab is reachable from the shell', (tester) async {
    await onboard(tester);

    expect(find.text('SENİN İÇİN'), findsOneWidget);

    await openTab(tester, 'FUAR ALANI');
    expect(find.text('Fuar Alanı'), findsOneWidget);

    await openTab(tester, 'AJANDA');
    expect(find.text('Ajanda'), findsOneWidget);

    await openTab(tester, 'PROFİL');
    expect(find.text('PROFİL'), findsWidgets);

    await openTab(tester, 'ANA SAYFA');
    expect(find.text('SENİN İÇİN'), findsOneWidget);
  });

  testWidgets('the fair hall survives a round trip through another tab', (
    tester,
  ) async {
    await onboard(tester);
    await openTab(tester, 'FUAR ALANI');

    // Nothing is selected on arrival, so the legend explains the grey boxes.
    expect(find.text('Boş standlar gri.'), findsOneWidget);
    final before = tester.state<ExpoSceneViewState>(
      find.byType(ExpoSceneView),
    );

    await openTab(tester, 'AJANDA');
    await openTab(tester, 'FUAR ALANI');

    expect(
      tester.state<ExpoSceneViewState>(find.byType(ExpoSceneView)),
      same(before),
      reason: 'the indexed stack must keep the camera, not rebuild it',
    );
  });

  testWidgets('editing interests on the profile reorders the home feed', (
    tester,
  ) async {
    await onboard(tester);
    await openTab(tester, 'PROFİL');

    final container = containerOf(tester);
    expect(container.read(recommendedSessionsProvider), hasLength(1));

    await scrollTo(tester, find.text('Havacılık & Uzay'));
    await tester.tap(find.text('Havacılık & Uzay'));
    await advance(tester, frames: 8);

    expect(
      container.read(recommendedSessionsProvider),
      hasLength(2),
      reason: 'a new interest must widen what the feed recommends',
    );
  });
}
