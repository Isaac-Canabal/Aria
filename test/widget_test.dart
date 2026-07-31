import 'package:aria/design/_gallery.dart';
import 'package:aria/design/nocturne.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

void main() {
  testWidgets('la galeria renderiza todos los componentes sin desbordar', (
    WidgetTester tester,
  ) async {
    await loadInter(tester);

    tester.view.physicalSize = const Size(1320, 4600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: nocturneTheme(),
        home: const Scaffold(body: GalleryScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Aria'), findsWidgets);
  });
}
