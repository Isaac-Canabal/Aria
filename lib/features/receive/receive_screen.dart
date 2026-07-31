/// "Recibir": el codigo que el emisor teclea.
library;

import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/transfer/transfer.dart';
import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivos el servidor y el anuncio mientras la pantalla exista.
    ref.watch(receiveServerProvider);
    ref.watch(announcementProvider);
    ref.watch(incomingProvider);

    final PairingService pairing = ref.watch(pairingServiceProvider);
    final PairingCode code =
        ref.watch(pairingCodeProvider).valueOrNull ?? pairing.current;

    return SyrodaScreen(
      topBar: const ScreenTopBar(title: 'Syroda'),
      body: ScreenCenter(
        gap: 20,
        padding: 28,
        children: <Widget>[
          if (pairing.isExpired)
            SyrodaButton(
              'Código caducado, generar uno nuevo',
              variant: SyrodaButtonVariant.primary,
              onPressed: pairing.regenerate,
            )
          else
            CodeCard(
              code: code.display,
              hint: 'Compártelo para que te envíen un archivo',
            ),
          Text(
            'o',
            style: NocturneType.at(
              12.5,
              color: NocturneColors.onText(0.5),
              height: 1.4,
            ),
          ),
          SyrodaButton(
            'Conectar manualmente',
            icon: SyrodaIcons.qr,
            onPressed: () => _showManualDetails(context, ref, code),
          ),
          const StatusLive('Esperando conexión…'),
        ],
      ),
    );
  }

  /// La salida cuando el descubrimiento no funciona: el emisor teclea la
  /// direccion. Reusa la tarjeta del codigo, sin componentes nuevos.
  Future<void> _showManualDetails(
    BuildContext context,
    WidgetRef ref,
    PairingCode code,
  ) async {
    final ReceiveServer? server = ref.read(receiveServerProvider).valueOrNull;
    final String? address = await localAddress();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: NocturneColors.neutral900.withValues(alpha: 0.5),
      builder: (BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(NocturneSpace.s4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SyrodaCard(
              elevation: SyrodaElevation.lg,
              borderRadius: NocturneRadius.brLg,
              padding: const EdgeInsets.all(NocturneSpace.s4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: NocturneSpace.s3,
                children: <Widget>[
                  Text('Conectar manualmente', style: NocturneType.h4),
                  Text(
                    'Si el otro dispositivo no aparece en la lista, que '
                    'escriba esta dirección y este código.',
                    style: NocturneType.at(
                      13.5,
                      color: NocturneColors.onText(0.65),
                      height: 1.5,
                    ),
                  ),
                  SyrodaRow(
                    title: address == null || server == null
                        ? 'Dirección no disponible'
                        : '$address:${server.port}',
                    subtitle: 'Dirección en esta red',
                    icon: SyrodaIcons.desktop,
                    iconStyle: SyrodaRowIconStyle.neutral,
                  ),
                  CodeCard(code: code.display),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SyrodaButton(
                      'Cerrar',
                      variant: SyrodaButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
