import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soft_drawer_service/soft_drawer_service.dart';

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
    final bytes = await renderDrawingImage(
      _documentWithRectangle(),
      pixelRatio: 0.5,
      quality: 90,
    );
    final image = img.decodeJpg(bytes);
    expect(image, isNotNull);
    expect(image!.width, 800);
    expect(image.height, 600);
  });

  test('white background, shapes drawn, no grid lines (AC 8, AC 9)', () async {
    final bytes = await renderDrawingImage(
      _documentWithRectangle(),
      pixelRatio: 1,
      quality: 95,
    );
    final image = img.decodeJpg(bytes)!;
    expect(_luminance(image, 0, 0), greaterThan(245), reason: 'corner');
    expect(_luminance(image, 10, 10), greaterThan(245), reason: 'grid line');
    expect(_luminance(image, 800, 600), greaterThan(245), reason: 'fill');
    // The default stroke is gray 0xFF757575 (spec 04, CL-1).
    expect(_luminance(image, 680, 600), lessThan(160), reason: 'left edge');
  });

  test('rejects exports above maxPixels before rendering (FR-26)', () async {
    expect(
      () => renderDrawingImage(DrawingDocument(), pixelRatio: 4, quality: 90),
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
      () => renderDrawingImage(DrawingDocument(), pixelRatio: 1, quality: 0),
      throwsArgumentError,
    );
    expect(
      () => renderDrawingImage(DrawingDocument(), pixelRatio: 0, quality: 90),
      throwsArgumentError,
    );
  });

  test('controller.exportImage uses the config defaults', () async {
    final controller = DrawingEditorController(
      config: const DrawingEditorConfig(canvasSize: Size(160, 120)),
    );
    final image = img.decodeJpg(await controller.exportImage())!;
    expect(image.width, 160);
    expect(image.height, 120);
    expect(
      () => DrawingEditorController(
        config: const DrawingEditorConfig(maxExportPixels: 100),
      ).exportImage(),
      throwsArgumentError,
    );
  });

  group('joints in the export (spec 02, AC 8)', () {
    DrawingDocument withJoint() => _documentWithRectangle().copyWith(
      joints: const [
        Joint(
          id: 'j',
          shapeId: 'r',
          anchorId: 'tr',
          name: 'J1',
          labelOffset: Offset(120, -120),
        ),
      ],
    );

    Future<img.Image> render(DrawingDocument document) async => img.decodeJpg(
      await renderDrawingImage(document, pixelRatio: 1, quality: 95),
    )!;

    num darkest(img.Image image, Rect area) {
      num result = 255;
      for (var y = area.top.toInt(); y < area.bottom; y++) {
        for (var x = area.left.toInt(); x < area.right; x++) {
          result = result < _luminance(image, x, y)
              ? result
              : _luminance(image, x, y);
        }
      }
      return result;
    }

    test('draws the label and the leader arrow', () async {
      {
        final plain = await render(_documentWithRectangle());
        final joined = await render(withJoint());
        // Label centered at (920 + 120, 530 - 120) = (1040, 410).
        final label = Rect.fromCenter(
          center: const Offset(1040, 410),
          width: 40,
          height: 24,
        );
        expect(darkest(plain, label), greaterThan(245));
        expect(darkest(joined, label), lessThan(100));
        // Midway along the leader, between label and anchor (920, 530).
        final leader = Rect.fromCenter(
          center: const Offset(980, 470),
          width: 6,
          height: 6,
        );
        expect(darkest(plain, leader), greaterThan(245));
        expect(darkest(joined, leader), lessThan(150));
      }
    });

    test('hidden joints are not exported (spec 04, JV-2)', () async {
      final plain = await render(_documentWithRectangle());
      final hidden = await render(withJoint().copyWith(jointsVisible: false));
      for (var y = 380; y < 540; y += 2) {
        for (var x = 900; x < 1080; x += 2) {
          expect(
            hidden.getPixel(x, y),
            plain.getPixel(x, y),
            reason: '($x, $y)',
          );
        }
      }
    });

    test('the label size changes the exported label (spec 04, JS-3)', () async {
      // Darkest column right of the label center, past the small label's
      // right edge but inside the large one's.
      final small = await render(withJoint());
      final large = await render(
        withJoint().copyWith(jointLabelSize: JointLabelSize.large),
      );
      num inkWidth(img.Image image) {
        var count = 0;
        for (var x = 960; x < 1120; x++) {
          if (darkest(image, Rect.fromLTWH(x.toDouble(), 395, 1, 30)) < 128) {
            count++;
          }
        }
        return count;
      }

      expect(inkWidth(large), greaterThan(inkWidth(small)));
    });

    test('adds no anchor dots: pixels away from the joint are '
        'identical', () async {
      {
        final plain = await render(_documentWithRectangle());
        final joined = await render(withJoint());
        // Around the bl anchor (680, 670), far from the joint at tr.
        for (var y = 650; y < 690; y++) {
          for (var x = 660; x < 700; x++) {
            expect(
              joined.getPixel(x, y),
              plain.getPixel(x, y),
              reason: '($x, $y)',
            );
          }
        }
      }
    });
  });
}
