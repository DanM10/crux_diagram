import 'package:flutter/widgets.dart';

import '../geometry/viewport.dart';
import '../model/drawing_document.dart';
import '../painting/document_painting.dart';
import '../painting/joint_style.dart';

/// A read-only widget that draws a [DrawingDocument] the way the image
/// export does (spec 06, VW-1): white canvas, shapes and joints, without
/// grid, handles or selection.
///
/// The canvas is scaled to fit the widget's box, keeping its aspect ratio,
/// and centered; the space around it stays transparent. The widget needs a
/// bounded size, for example inside a `SizedBox` or an `AspectRatio`. It
/// ignores gestures, so it can sit inside a list item, a button or a
/// `GestureDetector`.
class DrawingView extends StatelessWidget {
  /// Creates a viewer for [document].
  const DrawingView({
    super.key,
    required this.document,
    this.jointStyle = const JointStyle(),
    this.semanticLabel,
  });

  /// The drawing to show.
  final DrawingDocument document;

  /// Look of leader arrows and labels. Pass the style given to the editor
  /// so joints look the same.
  final JointStyle jointStyle;

  /// Description announced as an image; without it the widget is excluded
  /// from semantics.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.infinite,
      painter: _DrawingViewPainter(document, jointStyle),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: paint),
    );
  }
}

class _DrawingViewPainter extends CustomPainter {
  _DrawingViewPainter(this.document, this.jointStyle);

  final DrawingDocument document;
  final JointStyle jointStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final viewport = CanvasViewport.fit(document.canvasSize, size);
    canvas
      ..save()
      ..translate(viewport.origin.dx, viewport.origin.dy)
      ..scale(viewport.scale)
      ..clipRect(Offset.zero & document.canvasSize);
    paintDocument(canvas, document, jointStyle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrawingViewPainter old) =>
      old.document != document || old.jointStyle != jointStyle;
}
