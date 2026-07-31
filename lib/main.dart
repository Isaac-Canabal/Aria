import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/app_database.dart';
import 'design/nocturne.dart';
import 'features/shell/syroda_shell.dart';
import 'state/lifecycle.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // En escritorio sqflite corre sobre FFI, y hay que enchufarlo antes de que
  // nadie abra la base de datos.
  initDatabaseFactory();
  runApp(const ProviderScope(child: SyrodaApp()));
}

class SyrodaApp extends StatelessWidget {
  const SyrodaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Syroda',
    debugShowCheckedModeBanner: false,
    theme: nocturneTheme(),
    home: const LifecycleScope(
      child: Scaffold(body: SafeArea(child: SyrodaShell())),
    ),
  );
}
