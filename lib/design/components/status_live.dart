import 'package:flutter/widgets.dart';

import '../nocturne.dart';

/// `.status-live` — texto con un punto de acento que late. Es lo unico de los
/// mockups que la version estatica no podia mostrar.
class StatusLive extends StatefulWidget {
  const StatusLive(this.label, {super.key});

  final String label;

  @override
  State<StatusLive> createState() => _StatusLiveState();
}

class _StatusLiveState extends State<StatusLive>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  // `@keyframes pulse { 50% { opacity: .25 } }` con recorrido de ida y vuelta.
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.25,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: <Widget>[
      FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: NocturneColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
      Text(
        widget.label,
        style: NocturneType.at(
          12.5,
          color: NocturneColors.onText(0.6),
          height: 1.4,
        ),
      ),
    ],
  );
}
