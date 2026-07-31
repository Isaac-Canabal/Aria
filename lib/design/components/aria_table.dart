import 'package:flutter/widgets.dart';

import '../nocturne.dart';
import 'pressable.dart';

/// Una columna de `.table`: su encabezado y el peso con el que reparte el
/// ancho.
class AriaTableColumn {
  const AriaTableColumn(this.label, {this.flex = 1});

  final String label;
  final int flex;
}

/// `.table` — la tabla del historial de escritorio. Las lineas de fila se
/// desvanecen en los extremos: es una firma de Nocturne, y por eso son
/// degradados y no bordes.
class AriaTable extends StatelessWidget {
  const AriaTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
  });

  final List<AriaTableColumn> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      FadingRule(
        color: NocturneColors.divider,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NocturneSpace.s2),
          child: Row(
            children: <Widget>[
              for (final AriaTableColumn column in columns)
                Expanded(
                  flex: column.flex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NocturneSpace.s2,
                    ),
                    child: Text(
                      column.label.toUpperCase(),
                      style: NocturneType.at(
                        11,
                        color: NocturneColors.tableHead,
                        letterSpacing: 11 * 0.08,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      for (int r = 0; r < rows.length; r++)
        Pressable(
          onTap: onRowTap == null ? null : () => onRowTap!(r),
          builder: (BuildContext context, bool hovered, bool pressed) =>
              ColoredBox(
                color: hovered
                    ? NocturneColors.onText(0.04)
                    : const Color(0x00000000),
                child: FadingRule(
                  color: NocturneColors.onText(0.08),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: NocturneSpace.s2,
                    ),
                    child: Row(
                      children: <Widget>[
                        for (int c = 0; c < columns.length; c++)
                          Expanded(
                            flex: columns[c].flex,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: NocturneSpace.s2,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: c < rows[r].length
                                    ? rows[r][c]
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
    ],
  );

  /// El texto normal de una celda.
  static Widget cell(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: NocturneType.at(14, height: 1.4),
  );
}

/// La linea de 1px que se desvanece en los ultimos 48px de cada extremo.
class FadingRule extends StatelessWidget {
  const FadingRule({
    super.key,
    required this.child,
    required this.color,
    this.fade = 48,
  });

  final Widget child;
  final Color color;
  final double fade;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      child,
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double stop = width <= fade * 2 ? 0.5 : fade / width;
          return SizedBox(
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    color.withValues(alpha: 0),
                    color,
                    color,
                    color.withValues(alpha: 0),
                  ],
                  stops: <double>[0, stop, 1 - stop, 1],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
