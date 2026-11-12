import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/geometry/anchor_snapping.dart';
import 'package:soft_drawer_service/src/geometry/resize.dart';

Anchor _a(String id, Offset p) =>
    Anchor(id: id, kind: AnchorKind.vertex, position: p);

void main() {
  group('nearestAnchorSnap', () {
    test('inside the threshold returns the pair and the delta', () {
      final snap = nearestAnchorSnap(
        [_a('tl', const Offset(100, 100))],
        [_a('tr', const Offset(108, 94))],
        threshold: 12,
      );
      expect(snap, isNotNull);
      expect(snap!.from, const Offset(100, 100));
      expect(snap.to, const Offset(108, 94));
      expect(snap.delta, const Offset(8, -6));
    });

    test('outside or exactly past the threshold returns null', () {
      expect(
        nearestAnchorSnap(
          [_a('tl', const Offset(100, 100))],
          [_a('tr', const Offset(112.01, 100))],
          threshold: 12,
        ),
        isNull,
      );
    });

    test('only the nearest pair is applied (SN-1)', () {
      final snap = nearestAnchorSnap(
        [_a('tl', const Offset(0, 0)), _a('br', const Offset(100, 100))],
        [_a('x', const Offset(10, 0)), _a('y', const Offset(103, 100))],
        threshold: 12,
      );
      expect(snap!.delta, const Offset(3, 0));
    });
  });

  test('anchorIdForHandle maps every handle to its anchor', () {
    expect(anchorIdForHandle(ResizeHandle.topLeft), 'tl');
    expect(anchorIdForHandle(ResizeHandle.top), 'tc');
    expect(anchorIdForHandle(ResizeHandle.right), 'rc');
    expect(anchorIdForHandle(ResizeHandle.bottomRight), 'br');
    expect(anchorIdForHandle(ResizeHandle.left), 'lc');
  });
}
