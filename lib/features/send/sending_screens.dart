/// "Enviando", "Completado" y "Error al enviar".
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/transfer/transfer.dart';
import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';

/// "Enviando": el anillo con el porcentaje.
class SendingScreen extends ConsumerWidget {
  const SendingScreen({super.key, required this.state});

  final SendInProgress state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AriaScreen(
    topBar: ScreenTopBar.back(
      leading: RoundButton(
        icon: AriaIcons.close,
        iconSize: 15,
        strokeWidth: 1.8,
        semanticLabel: 'Cerrar',
        onPressed: () => ref.read(sendProvider.notifier).cancel(),
      ),
    ),
    body: ScreenCenter(
      gap: 22,
      children: <Widget>[
        TransferRing(value: state.fraction),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              state.fileName,
              textAlign: TextAlign.center,
              style: NocturneType.at(
                16,
                weight: NocturneType.medium,
                height: 1.35,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${formatBytes(state.totalBytes)} · enviando a '
                '${state.peerName}',
                textAlign: TextAlign.center,
                style: NocturneType.at(
                  13,
                  color: NocturneColors.onText(0.6),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    actions: ScreenActions(
      children: <Widget>[
        AriaButton(
          'Cancelar envío',
          onPressed: () => ref.read(sendProvider.notifier).cancel(),
        ),
      ],
    ),
  );
}

/// "Completado".
class SendCompletedScreen extends ConsumerWidget {
  const SendCompletedScreen({super.key, required this.state});

  final SendCompleted state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AriaScreen(
    body: ScreenCenter(
      children: <Widget>[
        AriaBadge.icon(
          AriaIcons.checkCircle,
          size: 76,
          iconSize: 34,
          strokeWidth: 1.8,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Envío completado',
              textAlign: TextAlign.center,
              style: NocturneType.h3,
            ),
            const SizedBox(height: NocturneSpace.s2),
            ScreenLede(
              '${state.fileName} se envió a ${state.peerName}',
            ),
          ],
        ),
        AriaTag(
          'Completado en ${state.elapsed.inSeconds}s',
          variant: AriaTagVariant.accent,
        ),
      ],
    ),
    actions: ScreenActions(
      children: <Widget>[
        AriaButton(
          'Enviar otro archivo',
          variant: AriaButtonVariant.primary,
          onPressed: () => ref.read(sendProvider.notifier).reset(),
        ),
        AriaButton(
          'Volver al inicio',
          variant: AriaButtonVariant.ghost,
          onPressed: () => ref.read(sendProvider.notifier).reset(),
        ),
      ],
    ),
  );
}

/// "Error al enviar".
class SendFailedScreen extends ConsumerWidget {
  const SendFailedScreen({super.key, required this.state});

  final SendFailed state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AriaScreen(
    body: ScreenCenter(
      children: <Widget>[
        AriaBadge.icon(
          AriaIcons.xCircle,
          size: 76,
          iconSize: 34,
          strokeWidth: 1.8,
          style: AriaBadgeStyle.neutral,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No se pudo enviar',
              textAlign: TextAlign.center,
              style: NocturneType.h3,
            ),
            const SizedBox(height: NocturneSpace.s2),
            ScreenLede(describeTransferError(state.error, state.peerName)),
          ],
        ),
        const AriaTag('Fallido'),
      ],
    ),
    actions: ScreenActions(
      children: <Widget>[
        AriaButton(
          'Reintentar',
          variant: AriaButtonVariant.primary,
          onPressed: () => ref.read(sendProvider.notifier).reset(),
        ),
        AriaButton(
          'Cancelar',
          variant: AriaButtonVariant.ghost,
          onPressed: () => ref.read(sendProvider.notifier).reset(),
        ),
      ],
    ),
  );
}

/// El texto en español de un error del transporte.
///
/// Los tipos viven en `core`, que no sabe de idioma; la traducción es de la
/// UI. Nada aquí puede afirmar cifrado ni conexión segura.
String describeTransferError(TransferError error, String peerName) =>
    switch (error) {
      AuthError(failure: AuthFailure.codeExpired) =>
        'El código de $peerName caducó. Pídele que genere uno nuevo.',
      AuthError(failure: AuthFailure.tooManyAttempts) =>
        'Se agotaron los intentos. $peerName generó un código nuevo.',
      AuthError() => 'El código no coincide con el que muestra $peerName.',
      ConnectionFailed(fault: ConnectionFault.timeout) =>
        'No hubo respuesta de $peerName. Puede que la red no permita '
            'conexiones entre dispositivos.',
      ConnectionFailed(fault: ConnectionFault.refused) =>
        '$peerName no está aceptando conexiones. Verifica que tenga Aria '
            'abierto en la pantalla Recibir.',
      ConnectionFailed() =>
        'Se perdió la conexión con $peerName. Verifica que ambos '
            'dispositivos estén cerca y conectados a la misma red.',
      IntegrityError() =>
        'El archivo llegó dañado a $peerName. Vuelve a intentarlo.',
      RejectedByPeer(reason: RejectionReason.insufficientSpace) =>
        '$peerName no tiene espacio suficiente.',
      RejectedByPeer(reason: RejectionReason.busy) =>
        '$peerName está recibiendo otra transferencia.',
      RejectedByPeer() => '$peerName rechazó la transferencia.',
      TransferCancelled(origin: CancelOrigin.remote) =>
        '$peerName canceló la transferencia.',
      TransferCancelled() => 'Cancelaste el envío.',
      TransferIoError() => 'No se pudo leer el archivo.',
      ProtocolError() =>
        '$peerName respondió algo inesperado. Puede que tenga otra versión '
            'de Aria.',
    };

/// Tamaño legible, con la coma decimal del español.
String formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} ${units[unit]}';
}
