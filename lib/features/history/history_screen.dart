/// "Historial" y su estado vacio.
library;

import 'package:flutter/material.dart'
    show ScaffoldMessenger, SnackBar, SnackBarBehavior;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/transfer_record.dart';
import '../../core/platform/open_received.dart';
import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';
import '../send/sending_screens.dart' show formatBytes;

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, this.onSend});

  /// Lleva a Enviar desde el estado vacio.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransferRecord> entries =
        ref.watch(historyProvider).valueOrNull ?? const <TransferRecord>[];

    return SyrodaScreen(
      topBar: const ScreenTopBar(title: 'Historial'),
      body: entries.isEmpty
          ? ScreenCenter(
              gap: 14,
              children: <Widget>[
                SyrodaBadge.icon(
                  SyrodaIcons.clock,
                  size: 64,
                  iconSize: 26,
                  style: SyrodaBadgeStyle.quiet,
                ),
                const EmptyMessage(
                  title: 'Aún no hay envíos',
                  hint: 'Tus archivos enviados y recibidos aparecerán aquí.',
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SyrodaButton(
                    'Enviar un archivo',
                    variant: SyrodaButtonVariant.primary,
                    onPressed: onSend,
                  ),
                ),
              ],
            )
          : ScreenBody(
              gap: 8,
              children: <Widget>[
                _DestinationCard(),
                for (final TransferRecord entry in entries)
                  SyrodaRow(
                    title: entry.fileName,
                    subtitle: _subtitle(entry),
                    icon: _iconFor(entry.fileName),
                    iconStyle: _iconStyle(entry),
                    density: SyrodaRowDensity.small,
                    muted: entry.status == TransferStatus.failed,
                    // Solo lo recibido tiene donde abrirse: lo enviado sigue
                    // donde la persona lo eligio, no lo movio nadie.
                    onTap: _canOpen(entry)
                        ? () => _open(context, ref, entry)
                        : null,
                    trailing: entry.status == TransferStatus.completed
                        ? const SyrodaTag(
                            'Completado',
                            variant: SyrodaTagVariant.accent,
                          )
                        : const SyrodaTag('Fallido'),
                  ),
              ],
            ),
    );
  }

  bool _canOpen(TransferRecord entry) =>
      entry.status == TransferStatus.completed &&
      entry.direction == TransferDirection.received &&
      (entry.localPath?.isNotEmpty ?? false);

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    TransferRecord entry,
  ) async {
    final OpenOutcome outcome = await ref
        .read(fileOpenerProvider)
        .open(entry.localPath!);
    if (!context.mounted) return;

    final String? message = openOutcomeMessage(outcome);
    // Un aviso corto, no una pantalla de error: no ha fallado ninguna
    // transferencia, y la fila sigue diciendo donde quedo el archivo.
    if (message != null) showBriefMessage(context, message);
  }

  String _subtitle(TransferRecord entry) {
    final String direction = entry.direction == TransferDirection.sent
        ? 'A'
        : 'De';
    return '$direction ${entry.peerName} · ${formatDate(entry.completedAt)} · '
        '${formatBytes(entry.sizeBytes)}';
  }

  SyrodaRowIconStyle _iconStyle(TransferRecord entry) => switch (entry.status) {
    TransferStatus.failed => SyrodaRowIconStyle.quiet,
    TransferStatus.completed =>
      _isImage(entry.fileName)
          ? SyrodaRowIconStyle.accent
          : SyrodaRowIconStyle.neutral,
  };

  SyrodaIconData _iconFor(String name) =>
      _isImage(name) ? SyrodaIcons.image : SyrodaIcons.file;

  bool _isImage(String name) {
    final String lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}

/// Donde queda lo recibido, con la accion de abrir la carpeta.
///
/// Se compone con `SyrodaRow`, el mismo patron de las demas filas: la carpeta
/// es una cosa mas de la lista, no un componente nuevo del design system.
class _DestinationCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? label = ref.watch(destinationLabelProvider).valueOrNull;
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: NocturneSpace.s2),
      child: SyrodaRow(
        title: 'Lo recibido se guarda aquí',
        subtitle: label,
        icon: SyrodaIcons.file,
        iconStyle: SyrodaRowIconStyle.neutral,
        density: SyrodaRowDensity.small,
        onTap: () async {
          final OpenOutcome outcome = await ref
              .read(fileOpenerProvider)
              .openFolder(label);
          if (!context.mounted) return;
          if (outcome != OpenOutcome.opened) {
            showBriefMessage(context, 'No se pudo abrir la carpeta');
          }
        },
      ),
    );
  }
}

/// Un aviso corto. No hay componente de aviso en los mockups porque no hay
/// ningun estado que lo pida: esto no es un fallo de transferencia, es que el
/// sistema no pudo abrir algo.
void showBriefMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: NocturneType.at(13, color: NocturneColors.text),
      ),
      backgroundColor: NocturneColors.surface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// "hoy, 14:32" / "ayer, 19:10" / "28/07, 09:47", como en los mockups.
String formatDate(DateTime utc, {DateTime? now}) {
  final DateTime local = utc.toLocal();
  final DateTime today = now?.toLocal() ?? DateTime.now();
  final String time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';

  final int days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;

  return switch (days) {
    0 => 'hoy, $time',
    1 => 'ayer, $time',
    _ =>
      '${local.day.toString().padLeft(2, '0')}/'
          '${local.month.toString().padLeft(2, '0')}, $time',
  };
}
