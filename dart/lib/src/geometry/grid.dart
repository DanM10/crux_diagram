import 'dart:math' as math;
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

/// The spacing of the finest grid lines drawn at [scale] dp per unit, in
/// canvas units (spec 05, section 2, GA-1).
///
/// Returns [gridSize] when minor lines are drawn, `gridSize × majorEvery`
/// when only major lines are drawn, and null when no line is drawn
/// (spec 03, GD-4). [gridLinesAlong] draws lines at this spacing.
double? visibleGridStep({
  required double gridSize,
  required int majorEvery,
  required double scale,
}) {
  bool readable(double spacing) =>
      spacing * scale >= minGridSpacingDp - gridSpacingToleranceDp;
  if (readable(gridSize)) return gridSize;
  final majorSpacing = gridSize * majorEvery;
  return readable(majorSpacing) ? majorSpacing : null;
}

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
  final step = visibleGridStep(
    gridSize: gridSize,
    majorEvery: majorEvery,
    scale: scale,
  );
  if (step == null) return const [];
  final minor = step == gridSize;
  // Positions are computed as i × step, not accumulated, so they do not
  // drift; the small slack keeps a line that lands on the far edge.
  final count = (extent / step + 1e-9).floor();
  return [
    for (var i = 0; i <= count; i++)
      (at: i * step, major: !minor || i % majorEvery == 0),
  ];
}

/// Tolerance, in quarter turns, of [isQuarterTurn].
const double quarterTurnTolerance = 1e-9;

/// Whether [radians] is a multiple of 90°, within [quarterTurnTolerance]
/// quarter turns.
bool isQuarterTurn(double radians) {
  final quarters = radians / (math.pi / 2);
  return (quarters - quarters.round()).abs() < quarterTurnTolerance;
}

/// Whether a shape at [rotation] has its width along the canvas y axis,
/// that is, it is turned by an odd number of quarter turns.
bool _swapsAxes(double rotation) => (rotation / (math.pi / 2)).round().isOdd;

/// The snapped center of a shape of [size] and [rotation] moved so its
/// center is at [center], with grid lines every [step] units
/// (spec 05, GA-3, GA-5).
///
/// At a multiple of 90° the bounding box edges snap: on each axis, the
/// edge nearest to a grid line lands on it (the lower edge on a tie).
/// At other rotations the center snaps to multiples of [step].
Offset snapMoveToGrid(
  Offset center, {
  required Size size,
  required double rotation,
  required double step,
}) {
  if (!isQuarterTurn(rotation)) return snapPointToGrid(center, step);
  final swap = _swapsAxes(rotation);
  final halfX = (swap ? size.height : size.width) / 2;
  final halfY = (swap ? size.width : size.height) / 2;
  double snapAxis(double c, double half) {
    final low = snapToMultiple(c - half, step) - (c - half);
    final high = snapToMultiple(c + half, step) - (c + half);
    return c + (high.abs() < low.abs() ? high : low);
  }

  return Offset(snapAxis(center.dx, halfX), snapAxis(center.dy, halfY));
}
