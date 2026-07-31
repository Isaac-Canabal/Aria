/// El permiso de dispositivos cercanos y el de notificaciones, para Enviar y
/// Recibir: las dos pantallas que descubren pares y las dos que corren bajo
/// el servicio en primer plano.
///
/// Sin mockup propio — los mockups no cubren el camino sin permiso — asi que
/// se compone con los mismos patrones que cualquier otro estado vacio
/// (`ScreenCenter` + `EmptyMessage` + boton), no con un componente nuevo.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/permissions.dart';
import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';

/// Envuelve la pantalla con el estado de permiso cuando `nearbyDevices` no
/// esta concedido. `builder` solo se llama concedido o donde no aplica
/// (Windows): nada lee `peersProvider` sin el permiso que el descubrimiento
/// necesita.
class DiscoveryPermissionGate extends ConsumerWidget {
  const DiscoveryPermissionGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mientras se resuelve el future se asume el mejor caso: no hay parpadeo
    // del aviso de permiso en el primer frame cuando ya esta concedido.
    final PermissionOutcome outcome =
        ref
            .watch(requestPermissionProvider(SyrodaPermission.nearbyDevices))
            .valueOrNull ??
        PermissionOutcome.granted;

    return switch (outcome) {
      PermissionOutcome.granted ||
      PermissionOutcome.notApplicable => builder(context),
      PermissionOutcome.denied => _PermissionScreen(
        title: 'Syroda necesita ver dispositivos cercanos',
        hint: 'Actívalo para buscar equipos y que te encuentren en tu red.',
        action: 'Activar acceso',
        onPressed: () => ref.invalidate(
          requestPermissionProvider(SyrodaPermission.nearbyDevices),
        ),
      ),
      PermissionOutcome.permanentlyDenied => _PermissionScreen(
        title: 'Sin acceso a dispositivos cercanos',
        hint: 'Actívalo desde los ajustes del sistema para poder usar Syroda.',
        action: 'Abrir ajustes',
        onPressed: () => ref.read(permissionServiceProvider).openSettings(),
      ),
    };
  }
}

class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.title,
    required this.hint,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String hint;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SyrodaScreen(
    topBar: const ScreenTopBar(title: 'Syroda'),
    body: ScreenCenter(
      children: <Widget>[
        EmptyMessage(title: title, hint: hint),
        SyrodaButton(
          action,
          variant: SyrodaButtonVariant.primary,
          onPressed: onPressed,
        ),
      ],
    ),
  );
}

/// Un aviso que no bloquea: sin `POST_NOTIFICATIONS` la transferencia sigue
/// igual, solo que el servicio en primer plano no puede mostrar su
/// notificacion. Solo aparece tras la denegacion permanente — pedirlo la
/// primera vez ya paso por el dialogo del sistema al entrar a la pantalla, y
/// mientras siga en un simple "denied" pedirlo de nuevo puede todavia
/// funcionar sin que haga falta decir nada.
class NotificationsPermissionBanner extends ConsumerWidget {
  const NotificationsPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PermissionOutcome outcome =
        ref
            .watch(requestPermissionProvider(SyrodaPermission.notifications))
            .valueOrNull ??
        PermissionOutcome.granted;

    if (outcome != PermissionOutcome.permanentlyDenied) {
      return const SizedBox.shrink();
    }

    return SyrodaCard(
      child: Row(
        spacing: NocturneSpace.s3,
        children: <Widget>[
          Expanded(
            child: Text(
              'Sin permiso de notificaciones: no verás el aviso de '
              'transferencia en curso.',
              style: NocturneType.at(12.5, color: NocturneColors.onText(0.7)),
            ),
          ),
          SyrodaButton(
            'Ajustes',
            variant: SyrodaButtonVariant.ghost,
            onPressed: () => ref.read(permissionServiceProvider).openSettings(),
          ),
        ],
      ),
    );
  }
}
