import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../geometry/joint_geometry.dart';
import '../geometry/text_measurer.dart';
import '../model/drawing_document.dart';
import '../model/shape_element.dart';
import '../model/shape_type.dart';
import 'flutter_text_measurer.dart';
import 'joint_painting.dart';
import 'joint_style.dart';

/// The structure version this package writes (spec 06, GEO-010).
const int geometryVersion = 1;

/// Font family reported for labels whose [JointStyle.labelStyle] sets none
/// (spec 06, GEO-036; `LABEL_FONT_FAMILY` in `@crux-diagram/core`).
const String labelFontFamily = 'Arial';

/// How a [ShapeGeometry] is drawn.
enum ShapeGeometryKind {
  /// A rectangle: square and rectangle shapes.
  rect,

  /// The ellipse inscribed in the box: circle shapes.
  ellipse,
}

/// One shape, ready to paint: translate to [center], rotate by [rotation]
/// and draw [kind] of [width] × [height] centered at the origin, with the
/// stroke centered on the outline (spec 06, GEO-021).
@immutable
class ShapeGeometry {
  /// Creates a shape geometry.
  const ShapeGeometry({
    required this.id,
    required this.kind,
    required this.center,
    required this.width,
    required this.height,
    required this.rotation,
    required this.fill,
    required this.stroke,
  });

  /// Reads the JSON object written by [toJson].
  factory ShapeGeometry.fromJson(Map<String, Object?> json) {
    final stroke = json['stroke'] as Map<String, Object?>?;
    return ShapeGeometry(
      id: json['id']! as String,
      kind: ShapeGeometryKind.values.byName(json['kind']! as String),
      center: _offset(json['center']),
      width: _double(json['width']),
      height: _double(json['height']),
      rotation: _double(json['rotation']),
      fill: (json['fill'] as num?)?.toInt(),
      stroke: stroke == null
          ? null
          : (
              color: (stroke['color']! as num).toInt(),
              width: _double(stroke['width']),
            ),
    );
  }

  /// The shape's id in the document.
  final String id;

  /// Rectangle or inscribed ellipse.
  final ShapeGeometryKind kind;

  /// Center in canvas units.
  final Offset center;

  /// Box width in canvas units.
  final double width;

  /// Box height in canvas units.
  final double height;

  /// Radians, clockwise with +y down.
  final double rotation;

  /// ARGB fill, or null when it is not painted (spec 06, GEO-022).
  final int? fill;

  /// ARGB stroke color and width, or null when it is not painted
  /// (spec 06, GEO-022).
  final ({int color, double width})? stroke;

  /// The JSON object of spec 06, with the keys of `@crux-diagram/core`.
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'center': _point(center),
    'width': width,
    'height': height,
    'rotation': rotation,
    'fill': fill,
    'stroke': stroke == null
        ? null
        : {'color': stroke!.color, 'width': stroke!.width},
  };
}

/// The label text of a [JointGeometry].
@immutable
class JointTextGeometry {
  /// Creates a label text geometry.
  const JointTextGeometry({
    required this.value,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.fontFamily,
    required this.bold,
    required this.color,
  });

  /// Reads the JSON object written by [toJson].
  factory JointTextGeometry.fromJson(Map<String, Object?> json) =>
      JointTextGeometry(
        value: json['value']! as String,
        x: _double(json['x']),
        y: _double(json['y']),
        width: _double(json['width']),
        height: _double(json['height']),
        fontSize: _double(json['fontSize']),
        fontFamily: json['fontFamily']! as String,
        bold: json['bold']! as bool,
        color: (json['color']! as num).toInt(),
      );

  /// The joint name.
  final String value;

  /// Left edge of the measured text box.
  final double x;

  /// Top edge of the measured text box.
  final double y;

  /// Measured text width.
  final double width;

  /// Measured text height.
  final double height;

  /// Font size: 30, 34 or 38 by default, by label size.
  final double fontSize;

  /// Font family the label is painted with.
  final String fontFamily;

  /// Whether the text is bold.
  final bool bold;

  /// ARGB text color.
  final int color;

  /// The JSON object of spec 06.
  Map<String, Object?> toJson() => {
    'value': value,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'bold': bold,
    'color': color,
  };
}

/// One joint, ready to paint: [line], then the filled [arrowhead], then
/// [text] (spec 06, section 6).
@immutable
class JointGeometry {
  /// Creates a joint geometry.
  const JointGeometry({
    required this.id,
    required this.anchor,
    required this.labelRect,
    required this.text,
    required this.line,
    required this.arrowhead,
    required this.lineWidth,
    required this.lineColor,
  });

  /// Reads the JSON object written by [toJson].
  factory JointGeometry.fromJson(Map<String, Object?> json) {
    final rect = json['labelRect']! as Map<String, Object?>;
    final line = json['line'] as Map<String, Object?>?;
    final head = json['arrowhead'] as List<Object?>?;
    return JointGeometry(
      id: json['id']! as String,
      anchor: _offset(json['anchor']),
      labelRect: Rect.fromLTWH(
        _double(rect['left']),
        _double(rect['top']),
        _double(rect['width']),
        _double(rect['height']),
      ),
      text: JointTextGeometry.fromJson(json['text']! as Map<String, Object?>),
      line: line == null
          ? null
          : (from: _offset(line['from']), to: _offset(line['to'])),
      arrowhead: head?.map(_offset).toList(growable: false),
      lineWidth: _double(json['lineWidth']),
      lineColor: (json['lineColor']! as num).toInt(),
    );
  }

  /// The joint's id in the document.
  final String id;

  /// Anchor position in canvas units.
  final Offset anchor;

  /// Padded label rectangle (FMT-042).
  final Rect labelRect;

  /// Label text.
  final JointTextGeometry text;

  /// From the arrow start to the arrowhead base, or null when it is not
  /// drawn (spec 06, GEO-034, GEO-035).
  final ({Offset from, Offset to})? line;

  /// `[tip, left, right]`, filled, or null when there is no arrow
  /// (spec 06, GEO-034).
  final List<Offset>? arrowhead;

  /// Leader line width.
  final double lineWidth;

  /// ARGB color of the line and the arrowhead.
  final int lineColor;

  /// The JSON object of spec 06.
  Map<String, Object?> toJson() => {
    'id': id,
    'anchor': _point(anchor),
    'labelRect': {
      'left': labelRect.left,
      'top': labelRect.top,
      'width': labelRect.width,
      'height': labelRect.height,
    },
    'text': text.toJson(),
    'line': line == null
        ? null
        : {'from': _point(line!.from), 'to': _point(line!.to)},
    'arrowhead': arrowhead?.map(_point).toList(),
    'lineWidth': lineWidth,
    'lineColor': lineColor,
  };
}

/// Paint-ready primitives of a document, in canvas units (spec 06).
///
/// A painter outside this package (a backend, the React editor) reproduces
/// the drawing from this structure alone. It is not part of the document:
/// store it next to it.
@immutable
class DrawingGeometry {
  /// Creates a drawing geometry.
  const DrawingGeometry({
    required this.canvas,
    required this.shapes,
    required this.joints,
  });

  /// Reads the JSON object written by [toJson]. Check untrusted input with
  /// `validateGeometry` first: this throws on a malformed structure.
  factory DrawingGeometry.fromJson(Map<String, Object?> json) {
    final version = json['geometryVersion'];
    if (version != geometryVersion) {
      throw FormatException(
        'Unsupported geometryVersion $version; the supported version is '
        '$geometryVersion.',
      );
    }
    final canvas = json['canvas']! as Map<String, Object?>;
    return DrawingGeometry(
      canvas: Size(_double(canvas['width']), _double(canvas['height'])),
      shapes: [
        for (final shape in json['shapes']! as List<Object?>)
          ShapeGeometry.fromJson(shape! as Map<String, Object?>),
      ],
      joints: [
        for (final joint in json['joints']! as List<Object?>)
          JointGeometry.fromJson(joint! as Map<String, Object?>),
      ],
    );
  }

  /// Canvas size, copied from the document (GEO-011).
  final Size canvas;

  /// Shapes back to front (GEO-020).
  final List<ShapeGeometry> shapes;

  /// Joints, painted above every shape (GEO-030, GEO-031).
  final List<JointGeometry> joints;

  /// The JSON object of spec 06, with the keys of `@crux-diagram/core`, so
  /// the same document gives the same JSON in both languages.
  Map<String, Object?> toJson() => {
    'geometryVersion': geometryVersion,
    'canvas': {'width': canvas.width, 'height': canvas.height},
    'shapes': [for (final shape in shapes) shape.toJson()],
    'joints': [for (final joint in joints) joint.toJson()],
  };
}

/// The paint-ready geometry of [document] (spec 06).
///
/// Pure: the same document, measurer and style give the same result
/// (GEO-002). The editor, the viewer and the image export paint from this
/// function, so the geometry is what they draw (GEO-003). [measurer]
/// defaults to a [FlutterTextMeasurer] with [style]'s label style, which is
/// what the editor measures with.
DrawingGeometry computeGeometry(
  DrawingDocument document, {
  JointStyle style = const JointStyle(),
  TextMeasurer? measurer,
}) => DrawingGeometry(
  canvas: document.canvasSize,
  shapes: [for (final shape in document.shapes) shapeGeometry(shape)],
  joints: [
    for (final placement in placeJoints(document, style, measurer: measurer))
      jointGeometry(placement, style, document),
  ],
);

/// A fill or stroke with no alpha, or a stroke with no width, is not
/// painted (GEO-022).
ShapeGeometry shapeGeometry(ShapeElement shape) => ShapeGeometry(
  id: shape.id,
  kind: shape.type == ShapeType.circle
      ? ShapeGeometryKind.ellipse
      : ShapeGeometryKind.rect,
  center: shape.center,
  width: shape.size.width,
  height: shape.size.height,
  rotation: shape.rotation,
  fill: shape.fill.a > 0 ? shape.fill.toARGB32() : null,
  stroke: shape.stroke.a > 0 && shape.strokeWidth > 0
      ? (color: shape.stroke.toARGB32(), width: shape.strokeWidth)
      : null,
);

/// Leader arrow and label of [placement] (FMT-043 to FMT-045, GEO-032 to
/// GEO-036): no arrow when the anchor is inside the label or the arrow would
/// start on it; no line when it would not reach past the arrowhead.
JointGeometry jointGeometry(
  JointPlacement placement,
  JointStyle style,
  DrawingDocument document,
) {
  final labelSize = document.jointLabelSize;
  final rect = placement.labelRect;
  final anchor = placement.anchor;
  final color = style.color.toARGB32();
  final text = JointTextGeometry(
    value: placement.joint.name,
    x: rect.left + style.labelPadding,
    y: rect.top + style.labelPadding,
    width: placement.textSize.width,
    height: placement.textSize.height,
    fontSize: style.labelFontSize(labelSize),
    fontFamily: style.labelStyle.fontFamily ?? labelFontFamily,
    bold: isBold(style.labelStyle),
    color: (style.labelStyle.color ?? style.color).toARGB32(),
  );
  ({Offset from, Offset to})? line;
  List<Offset>? arrowhead;
  final start = leaderLineStart(rect, anchor);
  if (start != null && start != anchor) {
    final size = style.arrowheadSize(labelSize);
    arrowhead = arrowheadPoints(
      from: start,
      tip: anchor,
      length: size.width,
      width: size.height,
    );
    final base = (arrowhead[1] + arrowhead[2]) / 2;
    if ((anchor - start).distance > size.width) {
      line = (from: start, to: base);
    }
  }
  return JointGeometry(
    id: placement.joint.id,
    anchor: anchor,
    labelRect: rect,
    text: text,
    line: line,
    arrowhead: arrowhead,
    lineWidth: style.lineWidth,
    lineColor: color,
  );
}

Map<String, Object?> _point(Offset point) => {'x': point.dx, 'y': point.dy};

Offset _offset(Object? json) {
  final point = json! as Map<String, Object?>;
  return Offset(_double(point['x']), _double(point['y']));
}

double _double(Object? value) => (value! as num).toDouble();
