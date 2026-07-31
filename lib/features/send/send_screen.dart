/// "Enviar - inicio": elegir archivo y destino.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/transfer/transfer.dart';
import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';
import '../shared/discovery_permission.dart';
import 'code_prompt.dart';
import 'manual_connect.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  List<OutgoingFile> _picked = const <OutgoingFile>[];

  /// Se cumple una sola vez, `discoveryGracePeriod` despues de abrir la
  /// pantalla. No se reinicia si aparecen y desaparecen pares: es el tiempo
  /// que ya lleva buscando, no el tiempo que lleva vacio ahora mismo.
  bool _gracePeriodElapsed = false;
  Timer? _graceTimer;

  @override
  void initState() {
    super.initState();
    _graceTimer = Timer(discoveryGracePeriod, () {
      if (mounted) setState(() => _gracePeriodElapsed = true);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

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
              if (peers.isEmpty && _gracePeriodElapsed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: NocturneSpace.s4,
                  children: <Widget>[
                    const EmptyMessage(
                      title: 'No aparece nadie',
                      hint:
                          'Puede ser que el otro equipo no tenga Recibir '
                          'abierto, o que la red bloquee el descubrimiento. '
                          'Si la red tiene aislamiento de clientes, conectar '
                          'manualmente tampoco va a funcionar — en ese caso, '
                          'probá el hotspot de tu teléfono.',
                    ),
                    SyrodaButton(
                      'Conectar manualmente',
                      variant: SyrodaButtonVariant.primary,
                      onPressed: _connectManually,
                    ),
                  ],
                )
              else
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

  /// La salida cuando el descubrimiento no encuentra a nadie: la persona
  /// teclea la direccion y el codigo que muestra el receptor. El par es
  /// sintetico — no vino de mDNS, asi que no tiene identificador ni nombre
  /// propio; se sabe de el solo lo que se tecleo.
  Future<void> _connectManually() async {
    if (_picked.isEmpty) {
      await _pick();
      if (_picked.isEmpty) return;
    }
    if (!mounted) return;

    final ManualConnection? connection = await askForManualConnection(context);
    if (connection == null || !mounted) return;

    final Peer peer = Peer(
      serviceName: 'manual:${connection.host}:${connection.port}',
      deviceId: '',
      name: connection.host,
      platform: DevicePlatform.unknown,
      host: connection.host,
      port: connection.port,
    );

    await ref
        .read(sendProvider.notifier)
        .send(peer: peer, code: connection.code, files: _picked);
    if (mounted) setState(() => _picked = const <OutgoingFile>[]);
  }
}
