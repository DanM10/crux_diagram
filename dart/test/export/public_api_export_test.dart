import 'dart:ui';

import 'package:flutter/painting.dart' show TextStyle;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:crux_diagram/crux_diagram.dart';

DrawingDocument _doc() => DrawingDocument(
  canvasSize: const Size(200, 100),
  shapes: [
    ShapeElement(
      id: 'r',
      type: ShapeType.rectangle,
      center: const Offset(100, 50),
      size: const Size(80, 40),
      strokeWidth: 4,
    ),
  ],
  joints: const [
    Joint(
      id: 'j',
      shapeId: 'r',
      anchorId: 'tr',
      name: 'J1',
      labelOffset: Offset(30, -30),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formats (spec 06, EX-1 to EX-5, AC 8, 9, 11)', () {
    test('signatures', () async {
      final jpg = await renderDrawingImage(_doc());
      expect(jpg.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
      final png = await renderDrawingImage(_doc(), format: ImageFormat.png);
      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    });

    test('PNG is white by default and keeps the size', () async {
      final png = img.decodePng(
        await renderDrawingImage(
          _doc(),
          format: ImageFormat.png,
          pixelRatio: 2,
        ),
      )!;
      expect([png.width, png.height], [400, 200]);
      final corner = png.getPixel(1, 1);
      expect([corner.r, corner.g, corner.b, corner.a], [255, 255, 255, 255]);
    });

    test('transparent PNG: background alpha 0, strokes opaque', () async {
      final png = img.decodePng(
        await renderDrawingImage(
          _doc(),
          format: ImageFormat.png,
          transparentBackground: true,
        ),
      )!;
      expect(png.getPixel(1, 1).a, 0);
      // Left edge of the rectangle stroke at x = 60.
      expect(png.getPixel(60, 50).a, 255);
    });

    test('quality is ignored for PNG', () async {
      final a = await renderDrawingImage(_doc(), format: ImageFormat.png);
      final b = await renderDrawingImage(
        _doc(),
        format: ImageFormat.png,
        quality: 1,
      );
      expect(b, a);
    });

    test('transparentBackground with JPEG throws (AC 10)', () {
      expect(
        () => renderDrawingImage(_doc(), transparentBackground: true),
        throwsArgumentError,
      );
      expect(
        () => DrawingEditorController(
          config: const DrawingEditorConfig(transparentBackground: true),
        ),
        throwsArgumentError,
      );
      expect(
        () => DrawingEditorController(
          initial: _doc(),
        ).exportImage(transparentBackground: true),
        throwsArgumentError,
      );
    });
  });

  group('renderDrawingImage vs controller (RD-1 to RD-3, AC 7)', () {
    for (final format in ImageFormat.values) {
      test('identical bytes for $format', () async {
        final controller = DrawingEditorController(initial: _doc());
        expect(
          await controller.exportImage(format: format, pixelRatio: 2),
          await renderDrawingImage(_doc(), format: format, pixelRatio: 2),
        );
      });
    }

    test('argument errors', () {
      expect(
        () => renderDrawingImage(_doc(), pixelRatio: 0),
        throwsArgumentError,
      );
      expect(
        () => renderDrawingImage(_doc(), quality: 101),
        throwsArgumentError,
      );
      expect(
        () => renderDrawingImage(_doc(), maxPixels: 10),
        throwsArgumentError,
      );
    });

    test('exportImage defaults come from the config', () async {
      final controller = DrawingEditorController(
        initial: _doc(),
        config: const DrawingEditorConfig(
          imageFormat: ImageFormat.png,
          transparentBackground: true,
        ),
      );
      final png = img.decodePng(await controller.exportImage())!;
      expect(png.getPixel(1, 1).a, 0);
      // An explicit JPEG export stays opaque.
      final jpg = await controller.exportImage(format: ImageFormat.jpeg);
      expect(jpg.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    });
  });

  test('joint color paints line, arrowhead and label (AC 3)', () async {
    Future<img.Image> render(JointStyle style) async => img.decodePng(
      await renderDrawingImage(
        _doc(),
        format: ImageFormat.png,
        pixelRatio: 2,
        jointStyle: style,
      ),
    )!;
    bool hasColor(img.Image image, int r, int g, int b) {
      for (final p in image) {
        if (p.r == r && p.g == g && p.b == b) return true;
      }
      return false;
    }

    final green = await render(const JointStyle(color: Color(0xFF2E7D32)));
    expect(hasColor(green, 0x2E, 0x7D, 0x32), isTrue);
    final both = await render(
      const JointStyle(
        color: Color(0xFF2E7D32),
        labelStyle: TextStyle(color: Color(0xFFC62828)),
      ),
    );
    expect(
      hasColor(both, 0x2E, 0x7D, 0x32),
      isTrue,
      reason: 'line stays green',
    );
    expect(hasColor(both, 0xC6, 0x28, 0x28), isTrue, reason: 'label red');
    expect(hasColor(green, 0xC6, 0x28, 0x28), isFalse);
  });
}
