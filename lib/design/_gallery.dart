/// Galeria de componentes. Solo para depuracion: no forma parte de la app.
///
/// Renderiza cada patron de `components/` en sus variantes, a tamano real,
/// para poder compararlo contra `index.html` lado a lado.
library;

import 'package:flutter/widgets.dart';

import 'components.dart';
import 'nocturne.dart';

/// El ancho util de la pantalla del telefono en los mockups: 412 menos los
/// 8px de bisel a cada lado.
const double _phoneWidth = 396;

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int _navIndex = 0;
  int _visibility = 1;
  bool _saveToGallery = true;
  bool _notifications = false;
  final TextEditingController _deviceName = TextEditingController(
    text: 'PC de mí',
  );

  @override
  void dispose() {
    _deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: NocturneColors.bg,
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 64, 56, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'COMPONENTES · NOCTURNE',
                  style: NocturneType.h6.copyWith(
                    color: NocturneColors.accent,
                  ),
                ),
                const SizedBox(height: NocturneSpace.s3),
                Text('Aria', style: NocturneType.h1),
                const SizedBox(height: NocturneSpace.s3),
                SizedBox(
                  width: 640,
                  child: Text(
                    'Los patrones que repiten los mockups, a tamaño real. '
                    'Cada bloque corresponde a una clase de css/aria.css o de '
                    'css/nocturne.css.',
                    style: NocturneType.body.copyWith(
                      color: NocturneColors.onText(0.75),
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                ..._sections(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _sections() => <Widget>[
    _Section(
      title: 'Iconos',
      subtitle: 'El sprite de index.html, trazo 1.6 sobre viewBox de 24',
      children: <Widget>[
        for (final (String name, AriaIconData icon) in _icons)
          _Item(
            label: name,
            child: AriaIcon(icon, size: 24, color: NocturneColors.text),
          ),
      ],
    ),
    _Section(
      title: 'Botones',
      subtitle: '.btn con sus variantes, tamaños y estado inhabilitado',
      children: <Widget>[
        _Item(
          label: 'primary',
          child: AriaButton(
            'Reintentar',
            variant: AriaButtonVariant.primary,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'secondary',
          child: AriaButton('Elegir archivos', onPressed: () {}),
        ),
        _Item(
          label: 'secondary + icono',
          child: AriaButton(
            'Escanear código QR',
            icon: AriaIcons.qr,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'ghost',
          child: AriaButton(
            'Volver al inicio',
            variant: AriaButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'sm',
          child: AriaButton(
            'Reintentar',
            size: AriaButtonSize.small,
            variant: AriaButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'icon',
          child: AriaButton.icon(AriaIcons.close, onPressed: () {}),
        ),
        _Item(
          label: 'inhabilitado',
          child: AriaButton(
            'Enviar',
            variant: AriaButtonVariant.primary,
            enabled: false,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'block',
          width: 260,
          child: AriaButton(
            'Enviar otro archivo',
            variant: AriaButtonVariant.primary,
            block: true,
            onPressed: () {},
          ),
        ),
      ],
    ),
    _Section(
      title: 'Etiquetas',
      subtitle: '.tag',
      children: const <Widget>[
        _Item(
          label: 'accent',
          child: AriaTag('Completado', variant: AriaTagVariant.accent),
        ),
        _Item(
          label: 'accent-2',
          child: AriaTag('Recibido', variant: AriaTagVariant.accent2),
        ),
        _Item(
          label: 'neutral',
          child: AriaTag('Fallido', variant: AriaTagVariant.neutral),
        ),
        _Item(
          label: 'outline',
          child: AriaTag('Cerca', variant: AriaTagVariant.outline),
        ),
      ],
    ),
    _Section(
      title: 'Insignias',
      subtitle: '.badge — el tamaño y el tinte cambian por instancia',
      children: <Widget>[
        _Item(
          label: 'accent 52',
          child: AriaBadge.icon(AriaIcons.send),
        ),
        _Item(
          label: 'accent 76',
          child: AriaBadge.icon(
            AriaIcons.checkCircle,
            size: 76,
            iconSize: 34,
            strokeWidth: 1.8,
          ),
        ),
        _Item(
          label: 'neutral 76',
          child: AriaBadge.icon(
            AriaIcons.xCircle,
            size: 76,
            iconSize: 34,
            strokeWidth: 1.8,
            style: AriaBadgeStyle.neutral,
          ),
        ),
        _Item(
          label: 'quiet 64',
          child: AriaBadge.icon(
            AriaIcons.clock,
            size: 64,
            iconSize: 26,
            style: AriaBadgeStyle.quiet,
          ),
        ),
        _Item(label: 'iniciales', child: AriaBadge.initials('TU')),
      ],
    ),
    _Section(
      title: 'Filas',
      subtitle: '.row en sus tres densidades',
      children: <Widget>[
        _Item(
          label: 'normal',
          width: _phoneWidth,
          child: const AriaRow(
            title: 'Pixel de Ana',
            subtitle: 'A 2 metros',
            icon: AriaIcons.phone,
            trailing: AriaTag('Cerca', variant: AriaTagVariant.outline),
          ),
        ),
        _Item(
          label: 'icono neutral',
          width: _phoneWidth,
          child: const AriaRow(
            title: 'PC de Luis',
            subtitle: 'Misma red Wi-Fi',
            icon: AriaIcons.desktop,
            iconStyle: AriaRowIconStyle.neutral,
            trailing: AriaTag('Cerca'),
          ),
        ),
        _Item(
          label: 'buscando',
          width: _phoneWidth,
          child: const AriaRow.scanning('Buscando más dispositivos…'),
        ),
        _Item(
          label: 'small',
          width: _phoneWidth,
          child: const AriaRow(
            title: 'Foto_playa.jpg',
            subtitle: 'A Ana · hoy, 14:32',
            icon: AriaIcons.image,
            density: AriaRowDensity.small,
            trailing: AriaTag('Completado', variant: AriaTagVariant.accent),
          ),
        ),
        _Item(
          label: 'small + muted',
          width: _phoneWidth,
          child: const AriaRow(
            title: 'Reporte_final.pdf',
            subtitle: 'A Ana · ayer, 19:10',
            icon: AriaIcons.file,
            iconStyle: AriaRowIconStyle.quiet,
            density: AriaRowDensity.small,
            muted: true,
            trailing: AriaTag('Fallido'),
          ),
        ),
        _Item(
          label: 'rail (escritorio)',
          width: 260,
          child: const AriaRow(
            title: 'Pixel de Ana',
            subtitle: 'A 3 metros',
            icon: AriaIcons.phone,
            density: AriaRowDensity.rail,
          ),
        ),
      ],
    ),
    _Section(
      title: 'Zona de soltar',
      subtitle: '.dropzone',
      children: <Widget>[
        _Item(
          label: 'móvil',
          width: _phoneWidth,
          child: Dropzone(
            title: 'Toca para elegir un archivo',
            hint: 'documentos, fotos o cualquier tipo',
            onTap: () {},
          ),
        ),
        _Item(
          label: 'escritorio',
          width: 420,
          child: Dropzone.desktop(
            title: 'Arrastra archivos aquí para enviarlos',
            hint: 'o elige un destino y selecciona un archivo desde tu PC',
            action: AriaButton('Elegir archivos', onPressed: () {}),
          ),
        ),
      ],
    ),
    _Section(
      title: 'Progreso',
      subtitle: '.pbar, el anillo de "Enviando" y .card.transfer',
      children: <Widget>[
        const _Item(
          label: 'barra 73%',
          width: 260,
          child: TransferProgress(value: 0.73),
        ),
        const _Item(
          label: 'barra fallida 41%',
          width: 260,
          child: TransferProgress(value: 0.41, failed: true),
        ),
        const _Item(
          label: 'anillo 64%',
          child: TransferRing(value: 0.64),
        ),
        _Item(
          label: 'tarjeta en curso',
          width: 520,
          child: TransferCard(
            name: 'Video_producto.mp4',
            status: '73%',
            value: 0.73,
            detail: 'A Pixel de Ana · 340 MB',
            trailing: AriaButton.icon(AriaIcons.close, onPressed: () {}),
          ),
        ),
        const _Item(
          label: 'tarjeta completada',
          width: 520,
          child: TransferCard(
            name: 'Mockups_v3.zip',
            status: '100%',
            value: 1,
            detail: 'A PC de Luis · 88 MB',
            icon: AriaIcons.image,
            trailing: AriaTag('Completado', variant: AriaTagVariant.accent),
          ),
        ),
        _Item(
          label: 'tarjeta fallida',
          width: 520,
          child: TransferCard(
            name: 'Reporte_final.pdf',
            status: 'Fallido',
            value: 0.41,
            detail: 'A Pixel de Ana · conexión perdida',
            iconStyle: AriaRowIconStyle.neutral,
            failed: true,
            trailing: AriaButton(
              'Reintentar',
              size: AriaButtonSize.small,
              variant: AriaButtonVariant.ghost,
              onPressed: () {},
            ),
          ),
        ),
      ],
    ),
    _Section(
      title: 'Código de emparejamiento',
      subtitle: '.code-card y .status-live',
      children: const <Widget>[
        _Item(
          label: 'tarjeta',
          width: 320,
          child: CodeCard(
            code: '482 913',
            hint: 'Compártelo para que te envíen un archivo',
          ),
        ),
        _Item(
          label: 'indicador',
          child: StatusLive('Esperando conexión…'),
        ),
      ],
    ),
    _Section(
      title: 'Interruptor',
      subtitle: '.toggle',
      children: <Widget>[
        _Item(
          label: 'activado',
          child: AriaToggle(value: true, onChanged: (_) {}),
        ),
        _Item(
          label: 'desactivado',
          child: AriaToggle(value: false, onChanged: (_) {}),
        ),
      ],
    ),
    _Section(
      title: 'Ajustes',
      subtitle: '.setting-list, con la variante ancha del escritorio',
      children: <Widget>[
        _Item(
          label: 'móvil',
          width: _phoneWidth,
          child: SettingList(
            children: <Widget>[
              const SettingTile(
                label: 'Nombre del dispositivo',
                value: 'Pixel de mí',
                showChevron: true,
              ),
              const SettingTile(
                label: 'Visibilidad',
                trailing: AriaTag(
                  'Solo dispositivos emparejados',
                  variant: AriaTagVariant.outline,
                ),
              ),
              SettingTile(
                label: 'Guardar fotos en Galería',
                trailing: AriaToggle(
                  value: _saveToGallery,
                  onChanged: (bool v) => setState(() => _saveToGallery = v),
                ),
              ),
              SettingTile(
                label: 'Notificaciones',
                trailing: AriaToggle(
                  value: _notifications,
                  onChanged: (bool v) => setState(() => _notifications = v),
                ),
              ),
              const SettingTile(label: 'Acerca de Aria', showChevron: true),
            ],
          ),
        ),
        _Item(
          label: 'escritorio (wide)',
          width: 472,
          child: SettingList(
            children: <Widget>[
              SettingTile(
                label: 'Guardar en Descargas',
                hint: 'Los archivos recibidos se guardan aquí automáticamente',
                wide: true,
                trailing: AriaToggle(
                  value: _saveToGallery,
                  onChanged: (bool v) => setState(() => _saveToGallery = v),
                ),
              ),
              SettingTile(
                label: 'Notificaciones de transferencia',
                hint: 'Avisar al completar o fallar un envío',
                wide: true,
                trailing: AriaToggle(
                  value: _notifications,
                  onChanged: (bool v) => setState(() => _notifications = v),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    _Section(
      title: 'Campos',
      subtitle: '.field, .input y .seg',
      children: <Widget>[
        _Item(
          label: 'campo de texto',
          width: 320,
          child: AriaField(
            label: 'Nombre del dispositivo',
            child: AriaInput(controller: _deviceName),
          ),
        ),
        _Item(
          // El ancho util del panel de ajustes de escritorio: 520 menos su
          // relleno de 24 a cada lado.
          label: 'segmentado',
          width: 472,
          child: AriaField(
            label: 'Visibilidad',
            child: AriaSegmented(
              options: const <String>[
                'Todos en la red local',
                'Solo dispositivos emparejados',
                'Nadie',
              ],
              selected: _visibility,
              onChanged: (int i) => setState(() => _visibility = i),
            ),
          ),
        ),
      ],
    ),
    _Section(
      title: 'Tabla',
      subtitle: '.table — las líneas de fila se desvanecen en los extremos',
      children: <Widget>[
        _Item(
          label: 'historial de escritorio',
          width: 868,
          child: AriaTable(
            columns: const <AriaTableColumn>[
              AriaTableColumn('Archivo', flex: 3),
              AriaTableColumn('Dirección', flex: 2),
              AriaTableColumn('Dispositivo', flex: 3),
              AriaTableColumn('Fecha', flex: 2),
              AriaTableColumn('Estado', flex: 2),
            ],
            rows: <List<Widget>>[
              <Widget>[
                AriaTable.cell('Foto_playa.jpg'),
                AriaTable.cell('Enviado'),
                AriaTable.cell('Pixel de Ana'),
                AriaTable.cell('Hoy, 14:32'),
                const AriaTag('Completado', variant: AriaTagVariant.accent),
              ],
              <Widget>[
                AriaTable.cell('Contrato_v2.docx'),
                AriaTable.cell('Recibido'),
                AriaTable.cell('PC de Luis'),
                AriaTable.cell('Hoy, 11:05'),
                const AriaTag('Completado', variant: AriaTagVariant.accent),
              ],
              <Widget>[
                AriaTable.cell('Reporte_final.pdf'),
                AriaTable.cell('Enviado'),
                AriaTable.cell('Pixel de Ana'),
                AriaTable.cell('Ayer, 19:10'),
                const AriaTag('Fallido'),
              ],
            ],
          ),
        ),
      ],
    ),
    _Section(
      title: 'Navegación inferior',
      subtitle: '.bottom-nav',
      children: <Widget>[
        _Item(
          label: 'cuatro secciones',
          width: _phoneWidth,
          child: BottomNav(
            items: BottomNav.ariaItems,
            currentIndex: _navIndex,
            onSelected: (int i) => setState(() => _navIndex = i),
          ),
        ),
      ],
    ),
    _Section(
      title: 'Barra de título de Windows',
      subtitle: '.win-titlebar',
      children: <Widget>[
        _Item(
          label: 'ventana principal',
          width: 600,
          child: WinTitleBar(
            title: 'Aria',
            onMinimize: () {},
            onMaximize: () {},
            onClose: () {},
          ),
        ),
      ],
    ),
    _Section(
      title: 'Andamiaje de pantalla',
      subtitle: '.screen-lede, .empty-title, .section-label, .round-btn',
      children: <Widget>[
        _Item(
          label: 'título y entradilla',
          width: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Envío completado',
                textAlign: TextAlign.center,
                style: NocturneType.h3,
              ),
              const SizedBox(height: NocturneSpace.s2),
              const ScreenLede(
                'Presentación_Q3.pdf se envió a Pixel de Ana',
              ),
            ],
          ),
        ),
        const _Item(
          label: 'estado vacío',
          width: 330,
          child: EmptyMessage(
            title: 'Aún no hay envíos',
            hint: 'Tus archivos enviados y recibidos aparecerán aquí.',
          ),
        ),
        const _Item(
          label: 'etiqueta de sección',
          width: 260,
          child: SectionLabel('Dispositivos cercanos', bottomGap: 0),
        ),
        _Item(
          label: 'botón redondo',
          child: RoundButton(
            icon: AriaIcons.gear,
            semanticLabel: 'Ajustes',
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'perfil',
          width: 300,
          child: const ProfileHeader(
            initials: 'TU',
            name: 'Tu dispositivo',
            device: 'Pixel 9',
          ),
        ),
      ],
    ),
  ];

  static const List<(String, AriaIconData)> _icons = <(String, AriaIconData)>[
    ('send', AriaIcons.send),
    ('receive', AriaIcons.receive),
    ('arrow-up', AriaIcons.arrowUp),
    ('clock', AriaIcons.clock),
    ('user', AriaIcons.user),
    ('gear', AriaIcons.gear),
    ('close', AriaIcons.close),
    ('check-circle', AriaIcons.checkCircle),
    ('x-circle', AriaIcons.xCircle),
    ('phone', AriaIcons.phone),
    ('desktop', AriaIcons.desktop),
    ('image', AriaIcons.image),
    ('file', AriaIcons.file),
    ('qr', AriaIcons.qr),
    ('win-min', AriaIcons.winMinimize),
    ('win-max', AriaIcons.winMaximize),
    ('win-close', AriaIcons.winClose),
  ];
}

/// Un bloque de la galeria: titulo, subtitulo y las variantes en flujo.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 72),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: NocturneType.h2),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: NocturneType.at(
            14,
            color: NocturneColors.onText(0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(spacing: 40, runSpacing: 32, children: children),
      ],
    ),
  );
}

/// Una variante con su nombre, como `.gal-item` en la galeria estatica.
class _Item extends StatelessWidget {
  const _Item({required this.label, required this.child, this.width});

  final String label;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: NocturneType.at(
            13,
            weight: NocturneType.medium,
            color: NocturneColors.onText(0.55),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}
