import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/joint_label_size.dart';

/// How a joint's leader line is drawn. Only straight lines exist today; the
/// enum leaves room for an elbow style.
enum LeaderStyle {
  /// One straight segment from the label to the anchor.
  straight,
}

/// Visual style of joints: leader arrows and labels (spec 02, section 7;
/// spec 04).
///
/// Lengths are in canvas units, so they scale with zoom and export.
@immutable
class JointStyle {
  /// Creates a joint style. Every value has a default from spec 02 or
  /// spec 04.
  const JointStyle({
    this.arrowColor = const Color(0xFF000000),
    this.lineWidth = 2.5,
    this.arrowheadLength = 16,
    this.arrowheadWidth = 11,
    this.labelStyle = const TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.bold,
    ),
    this.labelBaseFontSize = 30,
    this.labelFontSizeStep = 4,
    this.labelPadding = 6,
    this.selectionColor,
    this.leaderStyle = LeaderStyle.straight,
  }) : assert(labelBaseFontSize > 0),
       assert(labelFontSizeStep >= 0);

  /// Color of the leader line and arrowhead.
  final Color arrowColor;

  /// Leader line width. It does not change with the label size.
  final double lineWidth;

  /// Arrowhead length along the line at [JointLabelSize.small]; see
  /// [arrowheadSize].
  final double arrowheadLength;

  /// Arrowhead width across the line at [JointLabelSize.small]; see
  /// [arrowheadSize].
  final double arrowheadWidth;

  /// Text style of the joint name. Its `fontSize` is ignored: the size comes
  /// from [labelFontSize] (spec 04, JS-6).
  final TextStyle labelStyle;

  /// Font size of [JointLabelSize.small] labels, in canvas units.
  final double labelBaseFontSize;

  /// Font size added by each larger [JointLabelSize], in canvas units.
  final double labelFontSizeStep;

  /// Space between the text and the edge the leader line starts from.
  final double labelPadding;

  /// Highlight color of the selected joint; null uses the theme's primary
  /// color.
  final Color? selectionColor;

  /// Leader line shape.
  final LeaderStyle leaderStyle;

  /// Label font size for [size]: [labelBaseFontSize] plus one
  /// [labelFontSizeStep] per step above small (spec 04, JS-2).
  double labelFontSize(JointLabelSize size) =>
      labelBaseFontSize + size.index * labelFontSizeStep;

  /// Arrowhead length (width of the result) and width (height of the
  /// result) for [size]: [arrowheadLength] and [arrowheadWidth] scaled by
  /// `labelFontSize(size) / labelBaseFontSize` (spec 04, JS-7).
  Size arrowheadSize(JointLabelSize size) {
    final scale = labelFontSize(size) / labelBaseFontSize;
    return Size(arrowheadLength * scale, arrowheadWidth * scale);
  }

  @override
  bool operator ==(Object other) =>
      other is JointStyle &&
      other.arrowColor == arrowColor &&
      other.lineWidth == lineWidth &&
      other.arrowheadLength == arrowheadLength &&
      other.arrowheadWidth == arrowheadWidth &&
      other.labelStyle == labelStyle &&
      other.labelBaseFontSize == labelBaseFontSize &&
      other.labelFontSizeStep == labelFontSizeStep &&
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
    labelBaseFontSize,
    labelFontSizeStep,
    labelPadding,
    selectionColor,
    leaderStyle,
  );
}
