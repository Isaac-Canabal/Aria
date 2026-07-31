/// El armazon de la app movil: las cuatro secciones de la navegacion
/// inferior, y el flujo de envio que se pone por encima cuando hay una
/// transferencia en curso o recien terminada.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';
import '../history/history_screen.dart';
import '../receive/receive_screen.dart';
import '../send/send_screen.dart';
import '../send/sending_screens.dart';
import '../settings/profile_screen.dart';

class SyrodaShell extends ConsumerStatefulWidget {
  const SyrodaShell({super.key});

  @override
  ConsumerState<SyrodaShell> createState() => _SyrodaShellState();
}

class _SyrodaShellState extends ConsumerState<SyrodaShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final SendState send = ref.watch(sendProvider);

    // Enviando, Completado y Error toman la pantalla entera: en los mockups
    // no llevan navegacion inferior.
    final Widget? overlay = switch (send) {
      SendInProgress() => SendingScreen(state: send),
      SendCompleted() => SendCompletedScreen(state: send),
      SendFailed() => SendFailedScreen(state: send),
      SendIdle() => null,
    };
    if (overlay != null) return overlay;

    return ColoredBox(
      color: NocturneColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                SendScreen(onOpenSettings: () => _go(3)),
                // `IndexedStack` construye las cuatro pestanas aunque solo
                // pinte una, asi que Recibir tiene que saber si es la visible:
                // si no, se anuncia siempre.
                ReceiveScreen(active: _index == 1),
                HistoryScreen(onSend: () => _go(0)),
                const ProfileScreen(),
              ],
            ),
          ),
          BottomNav(
            items: BottomNav.syrodaItems,
            currentIndex: _index,
            onSelected: _go,
          ),
        ],
      ),
    );
  }
}
