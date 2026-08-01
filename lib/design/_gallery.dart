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
                  style: NocturneType.h6.copyWith(color: NocturneColors.accent),
                ),
                const SizedBox(height: NocturneSpace.s3),
                Text('Syroda', style: NocturneType.h1),
                const SizedBox(height: NocturneSpace.s3),
                SizedBox(
                  width: 640,
                  child: Text(
                    'Los patrones que repiten los mockups, a tamaño real. '
                    'Cada bloque corresponde a una clase de css/syroda.css o de '
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
        for (final (String name, SyrodaIconData icon) in _icons)
          _Item(
            label: name,
            child: SyrodaIcon(icon, size: 24, color: NocturneColors.text),
          ),
      ],
    ),
    _Section(
      title: 'Botones',
      subtitle: '.btn con sus variantes, tamaños y estado inhabilitado',
      children: <Widget>[
        _Item(
          label: 'primary',
          child: SyrodaButton(
            'Reintentar',
            variant: SyrodaButtonVariant.primary,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'secondary',
          child: SyrodaButton('Elegir archivos', onPressed: () {}),
        ),
        _Item(
          label: 'secondary + icono',
          child: SyrodaButton(
            'Escanear código QR',
            icon: SyrodaIcons.qr,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'ghost',
          child: SyrodaButton(
            'Volver al inicio',
            variant: SyrodaButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'sm',
          child: SyrodaButton(
            'Reintentar',
            size: SyrodaButtonSize.small,
            variant: SyrodaButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'icon',
          child: SyrodaButton.icon(SyrodaIcons.close, onPressed: () {}),
        ),
        _Item(
          label: 'inhabilitado',
          child: SyrodaButton(
            'Enviar',
            variant: SyrodaButtonVariant.primary,
            enabled: false,
            onPressed: () {},
          ),
        ),
        _Item(
          label: 'block',
          width: 260,
          child: SyrodaButton(
            'Enviar otro archivo',
            variant: SyrodaButtonVariant.primary,
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
          child: SyrodaTag('Completado', variant: SyrodaTagVariant.accent),
        ),
        _Item(
          label: 'accent-2',
          child: SyrodaTag('Recibido', variant: SyrodaTagVariant.accent2),
        ),
        _Item(
          label: 'neutral',
          child: SyrodaTag('Fallido', variant: SyrodaTagVariant.neutral),
        ),
        _Item(
          label: 'outline',
          child: SyrodaTag('Cerca', variant: SyrodaTagVariant.outline),
        ),
      ],
    ),
    _Section(
      title: 'Insignias',
      subtitle: '.badge — el tamaño y el tinte cambian por instancia',
      children: <Widget>[
        _Item(label: 'accent 52', child: SyrodaBadge.icon(SyrodaIcons.send)),
        _Item(
          label: 'accent 76',
          child: SyrodaBadge.icon(
            SyrodaIcons.checkCircle,
            size: 76,
            iconSize: 34,
            strokeWidth: 1.8,
          ),
        ),
        _Item(
          label: 'neutral 76',
          child: SyrodaBadge.icon(
            SyrodaIcons.xCircle,
            size: 76,
            iconSize: 34,
            strokeWidth: 1.8,
            style: SyrodaBadgeStyle.neutral,
          ),
        ),
        _Item(
          label: 'quiet 64',
          child: SyrodaBadge.icon(
            SyrodaIcons.clock,
            size: 64,
            iconSize: 26,
            style: SyrodaBadgeStyle.quiet,
          ),
        ),
        _Item(label: 'iniciales', child: SyrodaBadge.initials('TU')),
      ],
    ),
    _Section(
      title: 'Filas',
      subtitle: '.row en sus tres densidades',
      children: <Widget>[
        _Item(
          label: 'normal',
          width: _phoneWidth,
          child: const SyrodaRow(
            title: 'Pixel de Ana',
            subtitle: 'A 2 metros',
            icon: SyrodaIcons.phone,
            trailing: SyrodaTag('Cerca', variant: SyrodaTagVariant.outline),
          ),
        ),
        _Item(
          label: 'icono neutral',
          width: _phoneWidth,
          child: const SyrodaRow(
            title: 'PC de Luis',
            subtitle: 'Misma red Wi-Fi',
            icon: SyrodaIcons.desktop,
            iconStyle: SyrodaRowIconStyle.neutral,
            trailing: SyrodaTag('Cerca'),
          ),
        ),
        _Item(
          label: 'buscando',
          width: _phoneWidth,
          child: const SyrodaRow.scanning('Buscando más dispositivos…'),
        ),
        _Item(
          label: 'small',
          width: _phoneWidth,
          child: const SyrodaRow(
            title: 'Foto_playa.jpg',
            subtitle: 'A Ana · hoy, 14:32',
            icon: SyrodaIcons.image,
            density: SyrodaRowDensity.small,
            trailing: SyrodaTag('Completado', variant: SyrodaTagVariant.accent),
          ),
        ),
        _Item(
          label: 'small + muted',
          width: _phoneWidth,
          child: const SyrodaRow(
            title: 'Reporte_final.pdf',
            subtitle: 'A Ana · ayer, 19:10',
            icon: SyrodaIcons.file,
            iconStyle: SyrodaRowIconStyle.quiet,
            density: SyrodaRowDensity.small,
            muted: true,
            trailing: SyrodaTag('Fallido'),
          ),
        ),
        _Item(
          label: 'rail (escritorio)',
          width: 260,
          child: const SyrodaRow(
            title: 'Pixel de Ana',
            subtitle: 'A 3 metros',
            icon: SyrodaIcons.phone,
            density: SyrodaRowDensity.rail,
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
            action: SyrodaButton('Elegir archivos', onPressed: () {}),
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
        const _Item(label: 'anillo 64%', child: TransferRing(value: 0.64)),
        _Item(
          label: 'tarjeta en curso',
          width: 520,
          child: TransferCard(
            name: 'Video_producto.mp4',
            status: '73%',
            value: 0.73,
            detail: 'A Pixel de Ana · 340 MB',
            trailing: SyrodaButton.icon(SyrodaIcons.close, onPressed: () {}),
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
            icon: SyrodaIcons.image,
            trailing: SyrodaTag('Completado', variant: SyrodaTagVariant.accent),
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
            iconStyle: SyrodaRowIconStyle.neutral,
            failed: true,
            trailing: SyrodaButton(
              'Reintentar',
              size: SyrodaButtonSize.small,
              variant: SyrodaButtonVariant.ghost,
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
        _Item(label: 'indicador', child: StatusLive('Esperando conexión…')),
      ],
    ),
    _Section(
      title: 'Interruptor',
      subtitle: '.toggle',
      children: <Widget>[
        _Item(
          label: 'activado',
          child: SyrodaToggle(value: true, onChanged: (_) {}),
        ),
        _Item(
          label: 'desactivado',
          child: SyrodaToggle(value: false, onChanged: (_) {}),
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
                trailing: SyrodaTag(
                  'Solo dispositivos emparejados',
                  variant: SyrodaTagVariant.outline,
                ),
              ),
              const SettingTile(
                label: 'Carpeta de recibidos',
                value: 'Descargas/Syroda',
                showChevron: true,
              ),
              SettingTile(
                label: 'Notificaciones',
                trailing: SyrodaToggle(
                  value: _notifications,
                  onChanged: (bool v) => setState(() => _notifications = v),
                ),
              ),
              const SettingTile(label: 'Acerca de Syroda', showChevron: true),
            ],
          ),
        ),
        _Item(
          label: 'escritorio (wide)',
          width: 472,
          child: SettingList(
            children: <Widget>[
              const SettingTile(
                label: 'Carpeta de recibidos',
                hint: 'Dónde se guarda lo que llega de otros dispositivos',
                wide: true,
                value: r'C:\Users\yo\Downloads\Syroda',
                showChevron: true,
              ),
              SettingTile(
                label: 'Notificaciones de transferencia',
                hint: 'Avisar al completar o fallar un envío',
                wide: true,
                trailing: SyrodaToggle(
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
          child: SyrodaField(
            label: 'Nombre del dispositivo',
            child: SyrodaInput(controller: _deviceName),
          ),
        ),
        _Item(
          // El ancho util del panel de ajustes de escritorio: 520 menos su
          // relleno de 24 a cada lado.
          label: 'segmentado',
          width: 472,
          child: SyrodaField(
            label: 'Visibilidad',
            child: SyrodaSegmented(
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
          child: SyrodaTable(
            columns: const <SyrodaTableColumn>[
              SyrodaTableColumn('Archivo', flex: 3),
              SyrodaTableColumn('Dirección', flex: 2),
              SyrodaTableColumn('Dispositivo', flex: 3),
              SyrodaTableColumn('Fecha', flex: 2),
              SyrodaTableColumn('Estado', flex: 2),
            ],
            rows: <List<Widget>>[
              <Widget>[
                SyrodaTable.cell('Foto_playa.jpg'),
                SyrodaTable.cell('Enviado'),
                SyrodaTable.cell('Pixel de Ana'),
                SyrodaTable.cell('Hoy, 14:32'),
                const SyrodaTag('Completado', variant: SyrodaTagVariant.accent),
              ],
              <Widget>[
                SyrodaTable.cell('Contrato_v2.docx'),
                SyrodaTable.cell('Recibido'),
                SyrodaTable.cell('PC de Luis'),
                SyrodaTable.cell('Hoy, 11:05'),
                const SyrodaTag('Completado', variant: SyrodaTagVariant.accent),
              ],
              <Widget>[
                SyrodaTable.cell('Reporte_final.pdf'),
                SyrodaTable.cell('Enviado'),
                SyrodaTable.cell('Pixel de Ana'),
                SyrodaTable.cell('Ayer, 19:10'),
                const SyrodaTag('Fallido'),
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
            items: BottomNav.syrodaItems,
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
            title: 'Syroda',
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
              const ScreenLede('Presentación_Q3.pdf se envió a Pixel de Ana'),
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
          // Con el icono que lo usa de verdad: el cierre de "Enviando", que
          // es el unico `.round-btn` que queda en los mockups.
          child: RoundButton(
            icon: SyrodaIcons.close,
            iconSize: 15,
            strokeWidth: 1.8,
            semanticLabel: 'Cerrar',
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

  static const List<(String, SyrodaIconData)> _icons =
      <(String, SyrodaIconData)>[
        ('send', SyrodaIcons.send),
        ('receive', SyrodaIcons.receive),
        ('arrow-up', SyrodaIcons.arrowUp),
        ('clock', SyrodaIcons.clock),
        ('user', SyrodaIcons.user),
        ('close', SyrodaIcons.close),
        ('check-circle', SyrodaIcons.checkCircle),
        ('x-circle', SyrodaIcons.xCircle),
        ('phone', SyrodaIcons.phone),
        ('desktop', SyrodaIcons.desktop),
        ('image', SyrodaIcons.image),
        ('file', SyrodaIcons.file),
        ('qr', SyrodaIcons.qr),
        ('win-min', SyrodaIcons.winMinimize),
        ('win-max', SyrodaIcons.winMaximize),
        ('win-close', SyrodaIcons.winClose),
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
