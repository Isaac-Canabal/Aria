/// El emisor teclea el codigo que el receptor muestra.
///
/// Los mockups no traen esta pantalla, pero el codigo es lo unico que
/// autoriza una sesion, asi que tiene que haber donde escribirlo. Se compone
/// con los patrones que ya existen: tarjeta, campo y boton primario. Sin
/// componentes nuevos.
library;

import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/widgets.dart';

import '../../design/components.dart';
import '../../design/nocturne.dart';

/// Devuelve los seis digitos, o `null` si la persona se echo atras.
Future<String?> askForCode(BuildContext context, String peerName) =>
    showDialog<String>(
      context: context,
      barrierColor: NocturneColors.neutral900.withValues(alpha: 0.5),
      builder: (BuildContext context) => _CodeDialog(peerName: peerName),
    );

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.peerName});

  final String peerName;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final bool complete = _digits.length == 6;
      if (complete != _complete) setState(() => _complete = complete);
    });
  }

  /// El campo acepta el espacio de lectura ("482 913"), el protocolo no.
  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');

  @override
  void dispose() {
    _controller.dispose();
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
                Text('Código de ${widget.peerName}', style: NocturneType.h4),
                Text(
                  'Pídele el código de 6 dígitos que muestra su pantalla.',
                  style: NocturneType.at(
                    13.5,
                    color: NocturneColors.onText(0.65),
                    height: 1.5,
                  ),
                ),
                SyrodaField(
                  label: 'Código',
                  child: SyrodaInput(
                    controller: _controller,
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
                      'Enviar',
                      variant: SyrodaButtonVariant.primary,
                      enabled: _complete,
                      onPressed: () => Navigator.of(context).pop(_digits),
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
