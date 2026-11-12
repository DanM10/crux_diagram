import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../model/drawing_document.dart';
import '../painting/joint_painting.dart';
import '../painting/joint_style.dart';
import '../painting/shape_painting.dart';

/// Renders [document]'s shapes and joints over a white background and
/// encodes them as JPEG (spec 01, section 8; spec 02, section 7).
///
/// The image is `canvasSize × pixelRatio` pixels. Leader arrows and labels
/// use [jointStyle]; no grid, handles, selection, anchor dots or snap
/// highlights are drawn. Encoding runs in a separate isolate.
///
/// Throws [ArgumentError] when [pixelRatio] is not positive, [quality] is
/// outside 1 to 100, or the image would exceed [maxPixels] (checked before
/// rendering, FR-26).
Future<Uint8List> exportDocumentJpeg(
  DrawingDocument document, {
  required double pixelRatio,
  required int quality,
  required int maxPixels,
  JointStyle jointStyle = const JointStyle(),
}) async {
  if (pixelRatio <= 0) {
    throw ArgumentError.value(pixelRatio, 'pixelRatio', 'Must be positive.');
  }
  if (quality < 1 || quality > 100) {
    throw ArgumentError.value(quality, 'quality', 'Must be from 1 to 100.');
  }
  final width = (document.canvasSize.width * pixelRatio).round();
  final height = (document.canvasSize.height * pixelRatio).round();
  final pixels = width * height;
  if (pixels > maxPixels) {
    throw ArgumentError.value(
      pixelRatio,
      'pixelRatio',
      'The export would be ${width}x$height = $pixels pixels, above the '
          'maximum of $maxPixels.',
    );
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..scale(pixelRatio)
    ..drawRect(
      ui.Offset.zero & document.canvasSize,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  paintShapes(canvas, document.shapes);
  paintJoints(canvas, document, jointStyle);
  final picture = recorder.endRecording();
  final ui.Image image;
  try {
    image = await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
  final ByteData? rgba;
  try {
    rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  } finally {
    image.dispose();
  }
  if (rgba == null) {
    throw StateError('Could not read the rendered drawing pixels.');
  }
  final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
  return Isolate.run(() => _encode(bytes, width, height, quality));
}

Uint8List _encode(Uint8List rgba, int width, int height, int quality) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: quality);
}
