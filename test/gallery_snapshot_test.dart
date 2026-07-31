import 'dart:io';
import 'dart:ui' as ui;

import 'package:aria/design/_gallery.dart';
import 'package:aria/design/nocturne.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

/// Renderiza la galeria completa a PNG. Es el mecanismo con el que se compara
/// contra `index.html`: el destino sale de `ARIA_SNAPSHOT` o, si no esta,
/// queda en `build/gallery.png`.
void main() {
  testWidgets('la galeria se puede capturar a PNG', (
    WidgetTester tester,
  ) async {
    final GlobalKey key = GlobalKey();
    await loadInter(tester);

    tester.view.physicalSize = const Size(1320, 4600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: nocturneTheme(),
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: GalleryScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final String path =
          Platform.environment['ARIA_SNAPSHOT'] ?? 'build/gallery.png';
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });

    expect(tester.takeException(), isNull);
  });
}
