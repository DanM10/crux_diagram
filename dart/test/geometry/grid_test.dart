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
}
