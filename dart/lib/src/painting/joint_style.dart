import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How a joint's leader line is drawn. Only straight lines exist today; the
/// enum leaves room for an elbow style.
enum LeaderStyle {
  /// One straight segment from the label to the anchor.
  straight,
}

/// Visual style of joints: leader arrows and labels (spec 02, section 7).
///
/// Lengths are in canvas units, so they scale with zoom and export.
@immutable
class JointStyle {
  /// Creates a joint style. Every value has a default from spec 02.
  const JointStyle({
    this.arrowColor = const Color(0xFF000000),
    this.lineWidth = 1.5,
    this.arrowheadLength = 12,
    this.arrowheadWidth = 8,
    this.labelStyle = const TextStyle(color: Color(0xFF000000), fontSize: 28),
    this.labelPadding = 6,
    this.selectionColor,
    this.leaderStyle = LeaderStyle.straight,
  });

  /// Color of the leader line and arrowhead.
  final Color arrowColor;

  /// Leader line width.
  final double lineWidth;

  /// Arrowhead length along the line.
  final double arrowheadLength;

  /// Arrowhead width across the line.
  final double arrowheadWidth;

  /// Text style of the joint name.
  final TextStyle labelStyle;

  /// Space between the text and the edge the leader line starts from.
  final double labelPadding;

  /// Highlight color of the selected joint; null uses the theme's primary
  /// color.
  final Color? selectionColor;

  /// Leader line shape.
  final LeaderStyle leaderStyle;

  @override
  bool operator ==(Object other) =>
      other is JointStyle &&
      other.arrowColor == arrowColor &&
      other.lineWidth == lineWidth &&
      other.arrowheadLength == arrowheadLength &&
      other.arrowheadWidth == arrowheadWidth &&
      other.labelStyle == labelStyle &&
      other.labelPadding == labelPadding &&
      other.selectionColor == selectionColor &&
      other.leaderStyle == leaderStyle;

  @override
  int get hashCode => Object.hash(
    arrowColor,
    lineWidth,
    arrowheadLength,
    arrowheadWidth,
    labelStyle,
    labelPadding,
    selectionColor,
    leaderStyle,
  );
}
