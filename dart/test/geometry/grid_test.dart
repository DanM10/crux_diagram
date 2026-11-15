import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/geometry/grid.dart';

void main() {
  test('snapToMultiple rounds to the nearest multiple', () {
    expect(snapToMultiple(14.9, 10), 10);
    expect(snapToMultiple(15, 10), 20);
    expect(snapToMultiple(-4, 10), -0.0);
  });

  test('snapPointToGrid snaps both axes', () {
    expect(snapPointToGrid(const Offset(803, 597), 10), const Offset(800, 600));
  });

  group('gridLinesAlong (spec 03, GD-4, GD-5)', () {
    List<double> at(List<GridLine> lines, {required bool major}) => [
      for (final l in lines)
        if (l.major == major) l.at,
    ];

    test('at phone scale only major lines are drawn', () {
      // 360 dp across 1600 units: 0.225 dp per unit; minor 2.25 dp,
      // major 11.25 dp.
      final lines = gridLinesAlong(
        200,
        gridSize: 10,
        majorEvery: 5,
        scale: 0.225,
      );
      expect(at(lines, major: false), isEmpty);
      expect(at(lines, major: true), [0, 50, 100, 150, 200]);
    });

    test('at 4x both levels are drawn, majors never doubled as minors', () {
      final lines = gridLinesAlong(
        100,
        gridSize: 10,
        majorEvery: 5,
        scale: 0.9,
      );
      expect(at(lines, major: true), [0, 50, 100]);
      expect(at(lines, major: false), [10, 20, 30, 40, 60, 70, 80, 90]);
      expect(lines.map((l) => l.at).toSet(), hasLength(lines.length));
    });

    test('the 8 dp threshold holds on both sides, with a 1e-6 tolerance', () {
      bool minorDrawn(double scale) => gridLinesAlong(
        100,
        gridSize: 10,
        majorEvery: 5,
        scale: scale,
      ).any((l) => !l.major);
      expect(minorDrawn(0.8), isTrue, reason: 'exactly 8 dp');
      expect(minorDrawn(0.8 - 1e-8), isTrue, reason: 'within tolerance');
      expect(minorDrawn(0.8 - 1e-6), isFalse, reason: '7.99999 dp');

      bool majorDrawn(double scale) => gridLinesAlong(
        100,
        gridSize: 10,
        majorEvery: 5,
        scale: scale,
      ).isNotEmpty;
      expect(majorDrawn(0.16), isTrue, reason: 'major exactly 8 dp');
      expect(majorDrawn(0.16 - 1e-6), isFalse);
    });

    test('positions are multiples, not accumulated sums', () {
      final lines = gridLinesAlong(1, gridSize: 0.1, majorEvery: 5, scale: 100);
      expect(lines.last.at, closeTo(1, 1e-12));
      expect(lines, hasLength(11));
    });
  });
}
