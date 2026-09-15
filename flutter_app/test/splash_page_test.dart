import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_hospital_flutter/features/auth/presentation/pages/splash_page.dart';

void main() {
  testWidgets('shows a loading indicator on the splash background', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(Image), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF0062FB));

    final progressIndicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progressIndicator.color, Colors.white);
    expect(progressIndicator.strokeWidth, 2.5);

    final progressBox = tester.widget<SizedBox>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(SizedBox),
      ),
    );
    expect(progressBox.width, 28);
    expect(progressBox.height, 28);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value.statusBarColor, const Color(0xFF0062FB));
    expect(region.value.systemNavigationBarColor, const Color(0xFF0062FB));
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
  });
}
