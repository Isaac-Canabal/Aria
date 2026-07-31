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
    final AriaSettings? settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) {
      return const AriaScreen(
        topBar: ScreenTopBar(title: 'Perfil'),
        body: SizedBox.shrink(),
      );
    }

    final SettingsController controller = ref.read(settingsProvider.notifier);

    return AriaScreen(
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
                trailing: AriaTag(
                  visibilityLabel(settings.visibility),
                  variant: AriaTagVariant.outline,
                ),
                onTap: () => _editVisibility(context, controller, settings),
              ),
              SettingTile(
                label: 'Guardar fotos en Galería',
                trailing: AriaToggle(
                  value: settings.saveToGallery,
                  onChanged: controller.setSaveToGallery,
                ),
              ),
              SettingTile(
                label: 'Notificaciones',
                trailing: AriaToggle(
                  value: settings.notifications,
                  onChanged: controller.setNotifications,
                ),
              ),
              const SettingTile(label: 'Acerca de Aria', showChevron: true),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AriaButton(
              'Olvidar dispositivos emparejados',
              variant: AriaButtonVariant.ghost,
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
    AriaSettings settings,
  ) async {
    final TextEditingController field = TextEditingController(
      text: settings.deviceName,
    );
    final String? name = await _sheet<String>(
      context,
      title: 'Nombre del dispositivo',
      body: AriaField(label: 'Nombre', child: AriaInput(controller: field)),
      confirm: () => field.text,
    );
    field.dispose();
    if (name != null) await controller.setDeviceName(name);
  }

  Future<void> _editVisibility(
    BuildContext context,
    SettingsController controller,
    AriaSettings settings,
  ) async {
    final PeerVisibility? chosen = await _sheet<PeerVisibility>(
      context,
      title: 'Visibilidad',
      bodyBuilder: (void Function(PeerVisibility) pick) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          for (final PeerVisibility option in PeerVisibility.values)
            AriaRow(
              title: visibilityLabel(option),
              icon: AriaIcons.user,
              iconStyle: option == settings.visibility
                  ? AriaRowIconStyle.accent
                  : AriaRowIconStyle.neutral,
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
        child: AriaCard(
          elevation: AriaElevation.lg,
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
                  AriaButton(
                    'Cancelar',
                    variant: AriaButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (confirm != null)
                    AriaButton(
                      'Guardar',
                      variant: AriaButtonVariant.primary,
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
