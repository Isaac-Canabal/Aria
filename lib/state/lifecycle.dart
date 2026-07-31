/// Si la app esta en primer plano.
///
/// Decide si se acepta una sesion nueva: aceptar una que el proceso no puede
/// sostener es peor que no estar disponible. En Android 12+ arrancar un
/// servicio en primer plano desde background lanza
/// `ForegroundServiceStartNotAllowedException`, y para entonces la sesion ya
/// estaria autorizada y el archivo empezado.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La regla, aparte del widget para poder probarla.
///
/// `inactive` **no** apaga nada: Android lo emite al bajar la cortina de
/// notificaciones, al mostrar un dialogo de permisos y al entrar una llamada.
/// Apagarse ahi haria parpadear el dispositivo en la lista del emisor sin
/// causa visible.
bool isForeground(AppLifecycleState state) => switch (state) {
  AppLifecycleState.resumed || AppLifecycleState.inactive => true,
  AppLifecycleState.paused ||
  AppLifecycleState.hidden ||
  AppLifecycleState.detached => false,
};

final NotifierProvider<AppForeground, bool> appForegroundProvider =
    NotifierProvider<AppForeground, bool>(AppForeground.new);

class AppForeground extends Notifier<bool> {
  @override
  bool build() => true;

  void onStateChanged(AppLifecycleState lifecycle) {
    final bool next = isForeground(lifecycle);
    if (next != state) state = next;
    // El codigo NO rota aqui: quien lo dicta en voz alta y mira otra app
    // volveria a un codigo distinto sin que nada lo explique. Se renueva tras
    // un intento fallido, y caduca por tiempo, que si se puede explicar.
  }
}

/// Alimenta [appForegroundProvider] desde el ciclo de vida real.
class LifecycleScope extends ConsumerStatefulWidget {
  const LifecycleScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LifecycleScope> createState() => _LifecycleScopeState();
}

class _LifecycleScopeState extends ConsumerState<LifecycleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      ref.read(appForegroundProvider.notifier).onStateChanged(state);

  @override
  Widget build(BuildContext context) => widget.child;
}
