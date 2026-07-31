import 'package:flutter/widgets.dart';

/// Estados de puntero para los componentes que en el CSS cambian con `:hover`
/// y `:active`. Nocturne no usa ondas de Material: los rellenos son planos,
/// asi que no sirve `InkWell`.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered, bool pressed)
  builder;
  final VoidCallback? onTap;
  final bool enabled;
  final MouseCursor cursor;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final Widget child = widget.builder(
      context,
      _active && _hovered,
      _active && _pressed,
    );
    if (!_active) return child;

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: child,
      ),
    );
  }
}
