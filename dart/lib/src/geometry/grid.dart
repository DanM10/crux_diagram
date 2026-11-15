import 'dart:ui';

/// Rounds [value] to the nearest multiple of [step].
double snapToMultiple(double value, double step) =>
    (value / step).round() * step;

/// Snaps both coordinates of [point] to multiples of [gridSize].
Offset snapPointToGrid(Offset point, double gridSize) => Offset(
  snapToMultiple(point.dx, gridSize),
  snapToMultiple(point.dy, gridSize),
);

/// Smallest on-screen spacing, in dp, at which a grid level is drawn
/// (spec 03, GD-4).
const double minGridSpacingDp = 8;

/// Tolerance of the [minGridSpacingDp] comparison, in dp.
const double gridSpacingToleranceDp = 1e-6;

/// One grid line along an axis.
typedef GridLine = ({double at, bool major});

/// The grid lines to draw along an axis of [extent] canvas units at
/// [scale] dp per unit (spec 03, GD-4, GD-5).
///
/// Minor lines every [gridSize] units are included only when they are at
/// least [minGridSpacingDp] apart on screen, and major lines every
/// `gridSize × majorEvery` units only when those are. A position on a major
/// line is reported once, as major.
List<GridLine> gridLinesAlong(
  double extent, {
  required double gridSize,
  required int majorEvery,
  required double scale,
}) {
  bool readable(double spacing) =>
      spacing * scale >= minGridSpacingDp - gridSpacingToleranceDp;
  final minor = readable(gridSize);
  final majorSpacing = gridSize * majorEvery;
  if (!minor && !readable(majorSpacing)) return const [];
  final step = minor ? gridSize : majorSpacing;
  // Positions are computed as i × step, not accumulated, so they do not
  // drift; the small slack keeps a line that lands on the far edge.
  final count = (extent / step + 1e-9).floor();
  return [
    for (var i = 0; i <= count; i++)
      (at: i * step, major: !minor || i % majorEvery == 0),
  ];
}
