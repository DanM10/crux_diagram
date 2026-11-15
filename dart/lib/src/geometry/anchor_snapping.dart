import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'anchors.dart';
import 'resize.dart';

/// A snap that moves anchor position [from] onto anchor position [to].
@immutable
class AnchorSnap {
  /// Creates a snap.
  const AnchorSnap({
    required this.from,
    required this.to,
    required this.targetIndex,
  });

  /// Position of the moving shape's anchor before snapping.
  final Offset from;

  /// Position of the other shape's anchor.
  final Offset to;

  /// Index of the snapped-to anchor in the targets list.
  final int targetIndex;

  /// Translation that makes the two anchors coincide.
  Offset get delta => to - from;
}

/// The nearest pair between [moving] and [targets] at most [threshold]
/// apart, or null (spec 02, SN-1). On equal distances the first pair in
/// [moving] order wins.
AnchorSnap? nearestAnchorSnap(
  List<Anchor> moving,
  List<Anchor> targets, {
  required double threshold,
}) {
  AnchorSnap? best;
  var bestDistance = double.infinity;
  for (final from in moving) {
    for (var i = 0; i < targets.length; i++) {
      final to = targets[i];
      final distance = (to.position - from.position).distance;
      if (distance <= threshold && distance < bestDistance) {
        best = AnchorSnap(from: from.position, to: to.position, targetIndex: i);
        bestDistance = distance;
      }
    }
  }
  return best;
}

/// The anchor id that sits under [handle] (spec 02, SN-2). Circles have no
/// anchor under their corner handles.
String anchorIdForHandle(ResizeHandle handle) => switch (handle) {
  ResizeHandle.topLeft => 'tl',
  ResizeHandle.top => 'tc',
  ResizeHandle.topRight => 'tr',
  ResizeHandle.right => 'rc',
  ResizeHandle.bottomRight => 'br',
  ResizeHandle.bottom => 'bc',
  ResizeHandle.bottomLeft => 'bl',
  ResizeHandle.left => 'lc',
};
