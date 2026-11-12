import 'dart:ui';

/// Rounds [value] to the nearest multiple of [step].
double snapToMultiple(double value, double step) =>
    (value / step).round() * step;

/// Snaps both coordinates of [point] to multiples of [gridSize].
Offset snapPointToGrid(Offset point, double gridSize) => Offset(
  snapToMultiple(point.dx, gridSize),
  snapToMultiple(point.dy, gridSize),
);
