/// "Historial" y su estado vacio.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/transfer_record.dart';
import '../../design/components.dart';
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
                for (final TransferRecord entry in entries)
                  SyrodaRow(
                    title: entry.fileName,
                    subtitle: _subtitle(entry),
                    icon: _iconFor(entry.fileName),
                    iconStyle: _iconStyle(entry),
                    density: SyrodaRowDensity.small,
                    muted: entry.status == TransferStatus.failed,
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

  String _subtitle(TransferRecord entry) {
    final String direction = entry.direction == TransferDirection.sent
        ? 'A'
        : 'De';
    return '$direction ${entry.peerName} · ${formatDate(entry.completedAt)} · '
        '${formatBytes(entry.sizeBytes)}';
  }

  SyrodaRowIconStyle _iconStyle(TransferRecord entry) =>
      switch (entry.status) {
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
