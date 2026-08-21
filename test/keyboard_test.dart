import 'package:creathon/core/widgets/accent_button.dart';
import 'package:creathon/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

/// What the keyboard does to a form screen.
///
/// Every step of every signup is a Scaffold with a fixed footer over a
/// scrolling page, and the Scaffold already shrinks its body by the keyboard's
/// height. A screen that *also* pads by `MediaQuery.viewInsets` — read from a
/// context above that Scaffold, where the inset is still the full one — counts
/// the keyboard twice: the header leaves the top of the screen and a
/// keyboard-sized hole opens under the button. It looks exactly like a broken
/// layout, so it is worth a test with teeth.
void main() {
  setUpAll(loadAppFonts);

  /// Height of the fake keyboard, in logical pixels.
  const keyboard = 400.0;

  void openKeyboard(WidgetTester tester) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
  }

  double keyboardTopOf(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio - keyboard;

  for (final role in UserRole.values) {
    testWidgets('${role.label} signup keeps its footer above the keyboard', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await chooseRole(tester, role);

      openKeyboard(tester);
      await advance(tester, frames: 6);

      // The primary action sits just above the keyboard, not a keyboard's
      // height above it.
      final button = find.byType(AccentButton);
      final gap = keyboardTopOf(tester) - tester.getBottomLeft(button).dy;
      expect(
        gap,
        inInclusiveRange(0, 60),
        reason: 'the button must clear the keyboard by a margin, not a screen',
      );

      // And the header is still where it was, rather than pushed off the top.
      expect(tester.getTopLeft(find.text(role.label)).dy, lessThan(200));
      expect(find.text('E-POSTA'), findsOneWidget);
    });
  }

  testWidgets('the card form keeps its save button above the keyboard', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(
      tester,
      auth: auth,
      organizations: FakeOrganizationRepository(),
    );
    await completeEntrepreneurOnboarding(tester, auth: auth);

    await tester.tap(find.text('KARTIM'));
    await advance(tester, frames: 10);
    await tester.tap(find.text('DÜZENLE'));
    await advance(tester, frames: 12);

    openKeyboard(tester);
    await advance(tester, frames: 6);

    final gap =
        keyboardTopOf(tester) -
        tester.getBottomLeft(find.widgetWithText(AccentButton, 'Kaydet')).dy;
    expect(gap, inInclusiveRange(0, 60));
  });
}
