/// "Perfil / Ajustes".
library;

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
                label: 'Guardar fotos en Galería',
                trailing: SyrodaToggle(
                  value: settings.saveToGallery,
                  onChanged: controller.setSaveToGallery,
                ),
              ),
              SettingTile(
                label: 'Notificaciones',
                trailing: SyrodaToggle(
                  value: settings.notifications,
                  onChanged: controller.setNotifications,
                ),
              ),
              const SettingTile(label: 'Acerca de Syroda', showChevron: true),
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
                      'Cancelar',
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
