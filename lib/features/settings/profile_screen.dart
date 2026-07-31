/// "Perfil / Ajustes".
library;

import 'package:flutter/material.dart' show showDialog;
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
    final TextEditingController field = TextEditingController(
      text: settings.deviceName,
    );
    final String? name = await _sheet<String>(
      context,
      title: 'Nombre del dispositivo',
      body: SyrodaField(label: 'Nombre', child: SyrodaInput(controller: field)),
      confirm: () => field.text,
    );
    field.dispose();
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
  builder: (BuildContext context) => Center(
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
);
