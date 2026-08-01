/// "Perfil / Ajustes".
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/preferences.dart';
import '../../design/components.dart';
import '../../design/nocturne.dart';
import '../../state/state.dart';

/// Las etiquetas de visibilidad. El valor vive en `core`, que no sabe de
/// idioma; el texto es de aqui. Ninguna describe proteccion: el filtro es
/// conveniencia, no un control de seguridad.
String visibilityLabel(PeerVisibility visibility) => switch (visibility) {
  PeerVisibility.everyone => 'Todos en la red local',
  PeerVisibility.pairedOnly => 'Solo dispositivos emparejados',
  PeerVisibility.nobody => 'Nadie',
};

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyrodaSettings? settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) {
      return const SyrodaScreen(
        topBar: ScreenTopBar(title: 'Perfil'),
        body: SizedBox.shrink(),
      );
    }

    final SettingsController controller = ref.read(settingsProvider.notifier);

    return SyrodaScreen(
      topBar: const ScreenTopBar(title: 'Perfil'),
      body: ScreenBody(
        gap: 20,
        children: <Widget>[
          ProfileHeader(
            initials: _initialsOf(settings.deviceName),
            name: 'Tu dispositivo',
            device: settings.deviceName,
          ),
          SettingList(
            children: <Widget>[
              SettingTile(
                label: 'Nombre del dispositivo',
                value: settings.deviceName,
                showChevron: true,
                onTap: () => _editName(context, controller, settings),
              ),
              SettingTile(
                label: 'Visibilidad',
                trailing: SyrodaTag(
                  visibilityLabel(settings.visibility),
                  variant: SyrodaTagVariant.outline,
                ),
                onTap: () => _editVisibility(context, controller, settings),
              ),
              SettingTile(
                label: 'Carpeta de recibidos',
                value: ref.watch(destinationLabelProvider).valueOrNull,
                showChevron: true,
                onTap: () => _editDestination(context, ref, controller, settings),
              ),
              SettingTile(
                label: 'Notificaciones',
                trailing: SyrodaToggle(
                  value: settings.notifications,
                  onChanged: controller.setNotifications,
                ),
              ),
              SettingTile(
                label: 'Acerca de Syroda',
                showChevron: true,
                onTap: () => _showAbout(context),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SyrodaButton(
              'Olvidar dispositivos emparejados',
              variant: SyrodaButtonVariant.ghost,
              onPressed: () =>
                  ref.read(pairedDevicesProvider.notifier).forgetAll(),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsOf(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'TU';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _editName(
    BuildContext context,
    SettingsController controller,
    SyrodaSettings settings,
  ) async {
    // El `TextEditingController` lo posee `_NameField`, no esta funcion.
    //
    // Tenerlo aqui lo destruia demasiado pronto: el future de `showDialog`
    // completa cuando **empieza** el pop, no cuando el subarbol se desmonta,
    // asi que el `TextField` seguia montado y suscrito a un controller ya
    // destruido durante toda la animacion de salida. De ahi el
    // "A TextEditingController was used after being disposed", y de ahi la
    // cascada que acababa en `'_dependents.isEmpty': is not true`.
    String edited = settings.deviceName;
    final String? name = await _sheet<String>(
      context,
      title: 'Nombre del dispositivo',
      body: _NameField(
        initial: settings.deviceName,
        onChanged: (String value) => edited = value,
      ),
      confirm: () => edited,
    );
    if (name != null) await controller.setDeviceName(name);
  }

  /// Elegir donde se guarda lo recibido.
  ///
  /// Las dos plataformas no pueden ofrecer lo mismo, y fingir que si seria
  /// peor. En escritorio se elige una carpeta cualquiera con el dialogo del
  /// sistema. En Android el almacenamiento por ambitos no deja escribir en
  /// una ruta arbitraria: se elige la coleccion y el nombre, y MediaStore
  /// resuelve la ruta.
  Future<void> _editDestination(
    BuildContext context,
    WidgetRef ref,
    SettingsController controller,
    SyrodaSettings settings,
  ) async {
    if (!Platform.isAndroid) {
      final String? chosen = await FilePicker.getDirectoryPath(
        dialogTitle: 'Carpeta de recibidos',
        initialDirectory: settings.destinationPath,
      );
      if (chosen != null) await controller.setDestinationPath(chosen);
      return;
    }

    final _AndroidDestination? picked = await _sheet<_AndroidDestination>(
      context,
      title: 'Carpeta de recibidos',
      bodyBuilder: (void Function(_AndroidDestination) pick) =>
          _AndroidDestinationForm(settings: settings, onPick: pick),
    );
    if (picked == null) return;
    await controller.setDestinationFolder(
      collection: picked.collection,
      folder: picked.folder,
    );
  }

  /// Que es Syroda, en lo que de verdad hace.
  ///
  /// Sin la palabra "cifrado", sin candados y sin "conexion segura": el canal
  /// es pass-through en v1 y el copy no puede afirmar lo que no existe. Lo
  /// que si es cierto y se dice: los archivos van directos entre los dos
  /// equipos por la red local, y no hay servidores ni cuentas de por medio.
  Future<void> _showAbout(BuildContext context) => _sheet<void>(
    context,
    title: 'Acerca de Syroda',
    body: const _AboutText(),
    // No hay nada que cancelar aqui: solo se cierra.
    dismissLabel: 'Cerrar',
  );

  Future<void> _editVisibility(
    BuildContext context,
    SettingsController controller,
    SyrodaSettings settings,
  ) async {
    final PeerVisibility? chosen = await _sheet<PeerVisibility>(
      context,
      title: 'Visibilidad',
      bodyBuilder: (void Function(PeerVisibility) pick) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          for (final PeerVisibility option in PeerVisibility.values)
            SyrodaRow(
              title: visibilityLabel(option),
              icon: SyrodaIcons.user,
              iconStyle: option == settings.visibility
                  ? SyrodaRowIconStyle.accent
                  : SyrodaRowIconStyle.neutral,
              onTap: () => pick(option),
            ),
        ],
      ),
    );
    if (chosen != null) await controller.setVisibility(chosen);
  }
}

/// Lo que la persona elige en Android: coleccion y nombre de carpeta.
typedef _AndroidDestination = ({DestinationCollection collection, String folder});

/// El formulario de Android, con los patrones que ya existen: segmentado para
/// la coleccion y campo de texto para el nombre. Sin componentes nuevos.
class _AndroidDestinationForm extends StatefulWidget {
  const _AndroidDestinationForm({required this.settings, required this.onPick});

  final SyrodaSettings settings;
  final void Function(_AndroidDestination) onPick;

  @override
  State<_AndroidDestinationForm> createState() =>
      _AndroidDestinationFormState();
}

class _AndroidDestinationFormState extends State<_AndroidDestinationForm> {
  late DestinationCollection _collection = widget.settings.destinationCollection;

  // Dueno de su propio controller: el dialogo vuelve antes de desmontarse.
  late final TextEditingController _folder = TextEditingController(
    text: widget.settings.destinationFolder,
  );

  @override
  void dispose() {
    _folder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: NocturneSpace.s3,
    children: <Widget>[
      SyrodaField(
        label: 'Dónde',
        child: SyrodaSegmented(
          options: const <String>['Descargas', 'Documentos'],
          selected: _collection == DestinationCollection.documents ? 1 : 0,
          onChanged: (int index) => setState(
            () => _collection = index == 1
                ? DestinationCollection.documents
                : DestinationCollection.downloads,
          ),
        ),
      ),
      SyrodaField(
        label: 'Carpeta',
        child: SyrodaInput(controller: _folder),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: SyrodaButton(
          'Guardar',
          variant: SyrodaButtonVariant.primary,
          onPressed: () => widget.onPick((
            collection: _collection,
            folder: _folder.text,
          )),
        ),
      ),
    ],
  );
}

/// El texto de "Acerca de Syroda".
///
/// Solo afirma lo que la app hace hoy. Nada de cifrado, y nada que todavia no
/// exista: sin QR y sin modo claro, que son decisiones diferidas.
class _AboutText extends StatelessWidget {
  const _AboutText();

  static const List<String> _paragraphs = <String>[
    'Syroda envía archivos entre dispositivos que están en la misma red '
        'local: el teléfono y el computador de tu casa, dos equipos en la '
        'misma oficina.',
    'Los archivos van directos de un dispositivo al otro. No pasan por '
        'ningún servidor, no se suben a ninguna nube y no hacen falta '
        'cuentas: no hay con qué registrarse.',
    'Cada transferencia la autoriza un código de 6 dígitos que muestra quien '
        'recibe. Sin ese código no se acepta la conexión.',
    'Al terminar se comprueba que el archivo llegó completo y sin cambios. '
        'Si la comprobación falla, no se guarda a medias.',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: NocturneSpace.s3,
    children: <Widget>[
      for (final String paragraph in _paragraphs)
        Text(
          paragraph,
          style: NocturneType.at(
            13.5,
            color: NocturneColors.onText(0.75),
            height: 1.5,
          ),
        ),
    ],
  );
}

/// El campo de nombre, dueno de su propio controller.
///
/// Existe para que el controller viva y muera con el widget que lo usa, como
/// en `code_prompt.dart` y `manual_connect.dart`. Un controller de un dialogo
/// no puede pertenecer a quien lo abre: el que abre vuelve antes.
class _NameField extends StatefulWidget {
  const _NameField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_report);
  }

  void _report() => widget.onChanged(_controller.text);

  @override
  void dispose() {
    _controller.removeListener(_report);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SyrodaField(
    label: 'Nombre',
    child: SyrodaInput(controller: _controller),
  );
}

/// Una hoja con los patrones existentes: tarjeta elevada y botones.
Future<T?> _sheet<T>(
  BuildContext context, {
  required String title,
  Widget? body,
  Widget Function(void Function(T) pick)? bodyBuilder,
  T Function()? confirm,
  String dismissLabel = 'Cancelar',
}) => showDialog<T>(
  context: context,
  barrierColor: NocturneColors.neutral900.withValues(alpha: 0.5),
  // `Material.transparency`: `_editName` mete un `SyrodaInput` aqui, y el
  // `TextField` que lleva dentro exige un ancestro `Material` para pintar
  // cursor y seleccion. `showDialog` no pone uno solo — lo pone el
  // `Scaffold` de la ruta que abre el dialogo, que es un `OverlayEntry`
  // distinto del de este dialogo.
  builder: (BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(NocturneSpace.s4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SyrodaCard(
            elevation: SyrodaElevation.lg,
            borderRadius: NocturneRadius.brLg,
            padding: const EdgeInsets.all(NocturneSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: NocturneSpace.s3,
              children: <Widget>[
                Text(title, style: NocturneType.h4),
                ?body,
                if (bodyBuilder != null)
                  bodyBuilder((T value) => Navigator.of(context).pop(value)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: NocturneSpace.s2,
                  children: <Widget>[
                    SyrodaButton(
                      dismissLabel,
                      variant: SyrodaButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (confirm != null)
                      SyrodaButton(
                        'Guardar',
                        variant: SyrodaButtonVariant.primary,
                        onPressed: () => Navigator.of(context).pop(confirm()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
