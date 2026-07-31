import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga Inter en el entorno de pruebas.
///
/// Sin esto los tests miden con la fuente de relleno, cuyo glifo ocupa un em
/// cuadrado: todo texto sale mucho mas ancho que en la app y los
/// desbordamientos que reporta son falsos. La galeria existe para comparar
/// medidas contra `index.html`, asi que tiene que medir con la fuente real.
Future<void> loadInter(WidgetTester tester) => tester.runAsync(() async {
  final FontLoader loader = FontLoader('Inter');
  for (final String weight in <String>[
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
  ]) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  }
  await loader.load();
});
