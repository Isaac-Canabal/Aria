import 'package:flutter/widgets.dart';

import '../icons/aria_icon.dart';
import '../icons/aria_icons.dart';
import '../nocturne.dart';
import 'pressable.dart';

/// `.screen` — el andamiaje que comparten todas las pantallas moviles:
/// barra superior fija, cuerpo que crece, y navegacion o acciones abajo.
class AriaScreen extends StatelessWidget {
  const AriaScreen({
    super.key,
    this.topBar,
    required this.body,
    this.bottomNav,
    this.actions,
  });

  final Widget? topBar;
  final Widget body;

  /// La navegacion inferior, en las pantallas que la llevan.
  final Widget? bottomNav;

  /// `.screen-actions`, en las que terminan en botones.
  final Widget? actions;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: NocturneColors.bg,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?topBar,
        Expanded(child: body),
        ?actions,
        ?bottomNav,
      ],
    ),
  );
}

/// `.screen-topbar`
class ScreenTopBar extends StatelessWidget {
  const ScreenTopBar({super.key, required this.title, this.action})
    : leading = null;

  /// `.screen-topbar-back`: solo el boton de cerrar o volver.
  const ScreenTopBar.back({super.key, required this.leading})
    : title = null,
      action = null;

  final String? title;
  final Widget? action;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 14,
      bottom: leading != null ? 8 : 14,
    ),
    child: Row(
      mainAxisAlignment: leading != null
          ? MainAxisAlignment.start
          : MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (leading != null)
          leading!
        else ...<Widget>[
          Text(
            title!,
            style: NocturneType.at(
              20,
              weight: NocturneType.medium,
              height: 1.2,
            ),
          ),
          ?action,
        ],
      ],
    ),
  );
}

/// `.screen-body` — contenido que desplaza, con su propio ritmo vertical.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.children, this.gap = 24});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: children,
    ),
  );
}

/// `.screen-center` — pantallas de un solo mensaje: exito, error, vacio.
class ScreenCenter extends StatelessWidget {
  const ScreenCenter({
    super.key,
    required this.children,
    this.gap = 16,
    this.padding = 32,
  });

  final List<Widget> children;
  final double gap;
  final double padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: padding),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: gap,
      children: children,
    ),
  );
}

/// `.screen-actions`
class ScreenActions extends StatelessWidget {
  const ScreenActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: children,
    ),
  );
}

/// `.screen-lede` — el parrafo bajo un titulo de resultado.
class ScreenLede extends StatelessWidget {
  const ScreenLede(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: NocturneType.at(
      13.5,
      color: NocturneColors.onText(0.65),
      height: 1.5,
    ),
  );
}

/// `.empty-title` + `.empty-hint`
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({super.key, required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: <Widget>[
      Text(
        title,
        textAlign: TextAlign.center,
        style: NocturneType.at(15, weight: NocturneType.medium, height: 1.35),
      ),
      Text(
        hint,
        textAlign: TextAlign.center,
        style: NocturneType.at(
          12.5,
          color: NocturneColors.onText(0.6),
          height: 1.45,
        ),
      ),
    ],
  );
}

/// `.section-label` — el h6 que encabeza una lista.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.bottomGap = 10});

  final String text;
  final double bottomGap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomGap),
    child: Text(
      text.toUpperCase(),
      style: NocturneType.h6.copyWith(color: NocturneColors.onText(0.6)),
    ),
  );
}

/// `.round-btn` — el boton circular de la barra superior.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconSize = 17,
    this.strokeWidth = 1.5,
    this.semanticLabel,
  });

  final AriaIconData icon;
  final VoidCallback? onPressed;
  final double iconSize;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onPressed,
    builder: (BuildContext context, bool hovered, bool pressed) => Semantics(
      button: true,
      label: semanticLabel,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pressed
              ? Color.alphaBlend(
                  NocturneColors.activeNeutral,
                  NocturneColors.surface,
                )
              : hovered
              ? Color.alphaBlend(
                  NocturneColors.hoverNeutral,
                  NocturneColors.surface,
                )
              : NocturneColors.surface,
        ),
        child: AriaIcon(
          icon,
          size: iconSize,
          strokeWidth: strokeWidth,
          color: NocturneColors.text,
        ),
      ),
    ),
  );
}
