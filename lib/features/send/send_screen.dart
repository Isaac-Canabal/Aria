/// "Enviar - inicio": elegir archivo y destino.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/transfer/transfer.dart';
import '../../design/components.dart';
import '../../state/state.dart';
import '../shared/discovery_permission.dart';
import 'code_prompt.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  List<OutgoingFile> _picked = const <OutgoingFile>[];

  @override
  Widget build(BuildContext context) =>
      DiscoveryPermissionGate(builder: _build);

  Widget _build(BuildContext context) {
    final List<Peer> peers =
        ref.watch(peersProvider).valueOrNull ?? const <Peer>[];

    return SyrodaScreen(
      topBar: ScreenTopBar(
        title: 'Syroda',
        action: RoundButton(
          icon: SyrodaIcons.gear,
          semanticLabel: 'Ajustes',
          onPressed: widget.onOpenSettings,
        ),
      ),
      body: ScreenBody(
        children: <Widget>[
          const NotificationsPermissionBanner(),
          Dropzone(
            title: _picked.isEmpty
                ? 'Toca para elegir un archivo'
                : _pickedLabel,
            hint: 'documentos, fotos o cualquier tipo',
            onTap: _pick,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionLabel('Dispositivos cercanos'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: <Widget>[
                  for (final Peer peer in peers)
                    SyrodaRow(
                      title: peer.name,
                      subtitle: _subtitleFor(peer),
                      icon: peer.platform == DevicePlatform.android
                          ? SyrodaIcons.phone
                          : SyrodaIcons.desktop,
                      iconStyle: peer.platform == DevicePlatform.android
                          ? SyrodaRowIconStyle.accent
                          : SyrodaRowIconStyle.neutral,
                      trailing: _badgeFor(peer),
                      onTap: () => _sendTo(peer),
                    ),
                  const SyrodaRow.scanning('Buscando más dispositivos…'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _pickedLabel => _picked.length == 1
      ? _picked.single.name
      : '${_picked.length} archivos elegidos';

  /// El subtitulo de la fila. Los mockups muestran "A 2 metros", pero la
  /// distancia no se puede saber por mDNS: se dice lo que si es cierto.
  String _subtitleFor(Peer peer) => 'Misma red Wi-Fi';

  Widget? _badgeFor(Peer peer) {
    final Set<String> paired = ref.watch(pairedIdsProvider);
    // Sin candados ni "verificado": el filtro es conveniencia, no seguridad.
    if (!isPeerPaired(paired, peer)) return null;
    return const SyrodaTag('Conocido', variant: SyrodaTagVariant.outline);
  }

  Future<void> _pick() async {
    // En Android el selector va por SAF: no hace falta permiso de
    // almacenamiento, el sistema entrega el archivo ya autorizado.
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
    );
    if (result == null) return;

    final List<OutgoingFile> files = <OutgoingFile>[
      for (final PlatformFile file in result.files)
        if (file.path != null) await OutgoingFile.fromFile(File(file.path!)),
    ];
    if (mounted) setState(() => _picked = files);
  }

  Future<void> _sendTo(Peer peer) async {
    if (_picked.isEmpty) {
      await _pick();
      if (_picked.isEmpty) return;
    }
    if (!mounted) return;

    final String? code = await askForCode(context, peer.name);
    if (code == null || !mounted) return;

    await ref
        .read(sendProvider.notifier)
        .send(peer: peer, code: code, files: _picked);
    if (mounted) setState(() => _picked = const <OutgoingFile>[]);
  }
}
