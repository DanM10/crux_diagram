import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/export/jpeg_export.dart';

DrawingDocument _documentWithRectangle() => DrawingDocument(
  shapes: [
    ShapeElement(
      id: 'r',
      type: ShapeType.rectangle,
      center: const Offset(800, 600),
      size: const Size(240, 140),
      strokeWidth: 4,
    ),
  ],
);

num _luminance(img.Image image, int x, int y) =>
    img.getLuminance(image.getPixel(x, y));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports a decodable JPEG at canvas size × pixelRatio', () async {
    final bytes = await exportDocumentJpeg(
      _documentWithRectangle(),
      pixelRatio: 0.5,
      quality: 90,
      maxPixels: 16000000,
    );
    final image = img.decodeJpg(bytes);
    expect(image, isNotNull);
    expect(image!.width, 800);
    expect(image.height, 600);
  });

  test('white background, shapes drawn, no grid lines (AC 8, AC 9)', () async {
    final bytes = await exportDocumentJpeg(
      _documentWithRectangle(),
      pixelRatio: 1,
      quality: 95,
      maxPixels: 16000000,
    );
    final image = img.decodeJpg(bytes)!;
    expect(_luminance(image, 0, 0), greaterThan(245), reason: 'corner');
    expect(_luminance(image, 10, 10), greaterThan(245), reason: 'grid line');
    expect(_luminance(image, 800, 600), greaterThan(245), reason: 'fill');
    expect(_luminance(image, 680, 600), lessThan(100), reason: 'left edge');
  });

  test('rejects exports above maxPixels before rendering (FR-26)', () async {
    expect(
      () => exportDocumentJpeg(
        DrawingDocument(),
        pixelRatio: 4,
        quality: 90,
        maxPixels: 16000000,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message.toString(),
          'message',
          contains('30720000'),
        ),
      ),
    );
  });

  test('rejects a quality outside 1 to 100 and a non-positive pixel ratio', () {
    expect(
      () => exportDocumentJpeg(
        DrawingDocument(),
        pixelRatio: 1,
        quality: 0,
        maxPixels: 16000000,
      ),
      throwsArgumentError,
    );
    expect(
      () => exportDocumentJpeg(
        DrawingDocument(),
        pixelRatio: 0,
        quality: 90,
        maxPixels: 16000000,
      ),
      throwsArgumentError,
    );
  });

  test('controller.exportJpeg uses the config defaults', () async {
    final controller = DrawingEditorController(
      config: const DrawingEditorConfig(canvasSize: Size(160, 120)),
    );
    final image = img.decodeJpg(await controller.exportJpeg())!;
    expect(image.width, 160);
    expect(image.height, 120);
    expect(
      () => DrawingEditorController(
        config: const DrawingEditorConfig(maxExportPixels: 100),
      ).exportJpeg(),
      throwsArgumentError,
    );
  });
}
