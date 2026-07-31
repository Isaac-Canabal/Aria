/// El emisor teclea la dirección y el código cuando el descubrimiento no
/// encuentra a nadie.
///
/// Los mockups no traen esta pantalla. Se compone con los patrones que ya
/// existen: tarjeta, campo y botón primario — los mismos de `code_prompt.dart`
/// con un campo más. Sin componentes nuevos.
library;

import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/widgets.dart';

import '../../design/components.dart';
import '../../design/nocturne.dart';

/// Lo que hace falta para intentarlo sin haber descubierto al par:
/// dirección, puerto y código.
typedef ManualConnection = ({String host, int port, String code});

/// Devuelve la conexión tecleada, o `null` si la persona se echó atrás.
Future<ManualConnection?> askForManualConnection(BuildContext context) =>
    showDialog<ManualConnection>(
      context: context,
      barrierColor: NocturneColors.neutral900.withValues(alpha: 0.5),
      builder: (BuildContext context) => const _ManualConnectDialog(),
    );

class _ManualConnectDialog extends StatefulWidget {
  const _ManualConnectDialog();

  @override
  State<_ManualConnectDialog> createState() => _ManualConnectDialogState();
}

class _ManualConnectDialogState extends State<_ManualConnectDialog> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _code = TextEditingController();
  int? _port;

  @override
  void initState() {
    super.initState();
    _address.addListener(() => setState(() => _port = _portOf(_address.text)));
    _code.addListener(() => setState(() {}));
  }

  /// La direccion se escribe "192.168.1.23:54321", igual que la muestra el
  /// receptor: se parte por los dos puntos finales, nunca por los primeros,
  /// para no romper una IPv6 si algun dia hay que aceptarlas.
  int? _portOf(String address) {
    final int at = address.lastIndexOf(':');
    if (at <= 0 || at == address.length - 1) return null;
    return int.tryParse(address.substring(at + 1));
  }

  String get _host {
    final int at = _address.text.lastIndexOf(':');
    return at <= 0 ? _address.text : _address.text.substring(0, at);
  }

  String get _digits => _code.text.replaceAll(RegExp(r'\D'), '');

  bool get _complete =>
      _host.isNotEmpty && _port != null && _digits.length == 6;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  // `Material.transparency`: el campo de codigo es un `TextField` (dentro de
  // `SyrodaInput`), que exige un ancestro `Material` para pintar cursor y
  // selección. `showDialog` no pone uno solo — lo pone el `Scaffold` de la
  // ruta que lo abre, que es un `OverlayEntry` distinto del de este dialogo.
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(NocturneSpace.s4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SyrodaCard(
            elevation: SyrodaElevation.lg,
            borderRadius: NocturneRadius.brLg,
            padding: const EdgeInsets.all(NocturneSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: NocturneSpace.s3,
              children: <Widget>[
                Text('Conectar manualmente', style: NocturneType.h4),
                Text(
                  'Escribe la dirección que muestra el otro dispositivo y su '
                  'código de 6 dígitos.',
                  style: NocturneType.at(
                    13.5,
                    color: NocturneColors.onText(0.65),
                    height: 1.5,
                  ),
                ),
                SyrodaField(
                  label: 'Dirección (ej. 192.168.1.23:54321)',
                  child: SyrodaInput(controller: _address),
                ),
                SyrodaField(
                  label: 'Código',
                  child: SyrodaInput(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: NocturneSpace.s2,
                  children: <Widget>[
                    SyrodaButton(
                      'Cancelar',
                      variant: SyrodaButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    SyrodaButton(
                      'Conectar',
                      variant: SyrodaButtonVariant.primary,
                      enabled: _complete,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop((host: _host, port: _port!, code: _digits)),
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
}
