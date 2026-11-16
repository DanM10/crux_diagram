import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../model/drawing_document.dart';
import '../painting/document_painting.dart';
import '../painting/joint_style.dart';
import 'image_format.dart';

/// Renders [document] and encodes it as [format] (spec 06, RD-1).
///
/// The image is `canvasSize × pixelRatio` pixels, drawn over a white
/// background unless [transparentBackground] is true. Leader arrows and
/// labels use [jointStyle]; no grid, handles, selection, anchor dots or
/// snap highlights are drawn. Encoding runs in a separate isolate.
///
/// [quality] (1 to 100) only applies to [ImageFormat.jpeg]; PNG is lossless
/// and ignores it. [transparentBackground] is only valid with
/// [ImageFormat.png].
///
/// Throws [ArgumentError] when [pixelRatio] is not positive, [quality] is
/// outside 1 to 100, [transparentBackground] is combined with JPEG, or the
/// image would exceed [maxPixels] (checked before rendering).
///
/// Rendering uses `dart:ui`, so it runs inside a Flutter app or
/// `flutter test`, not on a pure Dart server.
Future<Uint8List> renderDrawingImage(
  DrawingDocument document, {
  ImageFormat format = ImageFormat.jpeg,
  double pixelRatio = 1.0,
  int quality = 90,
  int maxPixels = 16000000,
  bool transparentBackground = false,
  JointStyle jointStyle = const JointStyle(),
}) async {
  if (pixelRatio <= 0) {
    throw ArgumentError.value(pixelRatio, 'pixelRatio', 'Must be positive.');
  }
  if (quality < 1 || quality > 100) {
    throw ArgumentError.value(quality, 'quality', 'Must be from 1 to 100.');
  }
  if (transparentBackground && format != ImageFormat.png) {
    throw ArgumentError.value(
      transparentBackground,
      'transparentBackground',
      'Only valid with ImageFormat.png.',
    );
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
  final canvas = ui.Canvas(recorder)..scale(pixelRatio);
  paintDocument(
    canvas,
    document,
    jointStyle,
    background: !transparentBackground,
  );
  final picture = recorder.endRecording();
  final ui.Image image;
  try {
    image = await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
  final ByteData? rgba;
  try {
    rgba = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  } finally {
    image.dispose();
  }
  if (rgba == null) {
    throw StateError('Could not read the rendered drawing pixels.');
  }
  final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
  return Isolate.run(() => _encode(bytes, width, height, format, quality));
}

Uint8List _encode(
  Uint8List rgba,
  int width,
  int height,
  ImageFormat format,
  int quality,
) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return switch (format) {
    ImageFormat.jpeg => img.encodeJpg(image, quality: quality),
    ImageFormat.png => img.encodePng(image),
  };
}
