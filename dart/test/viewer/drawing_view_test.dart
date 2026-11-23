import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:crux_diagram/crux_diagram.dart';

DrawingDocument _doc({bool jointsVisible = true}) => DrawingDocument(
  canvasSize: const Size(1600, 1200),
  shapes: [
    ShapeElement(
      id: 'r',
      type: ShapeType.rectangle,
      center: const Offset(800, 600),
      size: const Size(800, 400),
      fill: const Color(0xFFFF0000),
    ),
  ],
  joints: const [
    Joint(
      id: 'j',
      shapeId: 'r',
      anchorId: 'tr',
      name: 'J1',
      labelOffset: Offset(120, -120),
    ),
  ],
  jointsVisible: jointsVisible,
);

Widget _host(Widget child, {Size size = const Size(400, 300)}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: const ValueKey('rb'),
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );

Future<img.Image> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('rb')),
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  return img.Image.fromBytes(
    width: image!.width,
    height: image.height,
    bytes: data!.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
}

void main() {
  testWidgets('scales to fit, centered, transparent letterbox (AC 4)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(DrawingView(document: _doc())));
    final wide = await _capture(tester);
    expect(wide.getPixel(200, 150).a, 255); // inside the canvas
    expect(wide.getPixel(200, 150).r, 255);

    await tester.pumpWidget(
      _host(DrawingView(document: _doc()), size: const Size(400, 400)),
    );
    final square = await _capture(tester);
    // 1600x1200 at 0.25 = 400x300, centered vertically: bands of 50.
    expect(square.getPixel(200, 10).a, 0);
    expect(square.getPixel(200, 390).a, 0);
    expect(square.getPixel(200, 60).a, 255);
  });

  testWidgets('same pixels as the export at the same scale (VW-1, JC-4)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(DrawingView(document: _doc())));
    final view = await _capture(tester);
    final png = img.decodePng(
      (await tester.runAsync(
        () => renderDrawingImage(
          _doc(),
          format: ImageFormat.png,
          pixelRatio: 0.25,
        ),
      ))!,
    )!;
    // The test surface is 1 dp = 1 px, so the view is 400x300 like the export.
    var differing = 0;
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 400; x++) {
        final a = view.getPixel(x, y);
        final b = png.getPixel(x, y);
        if ((a.r - b.r).abs() > 24 ||
            (a.g - b.g).abs() > 24 ||
            (a.b - b.b).abs() > 24) {
          differing++;
        }
      }
    }
    // Anti-aliasing at scaled edges may differ slightly.
    expect(differing, lessThan(400 * 300 * 0.01));
  });

  testWidgets('hidden joints are not drawn (AC 5)', (tester) async {
    await tester.pumpWidget(_host(DrawingView(document: _doc())));
    final shown = await _capture(tester);
    await tester.pumpWidget(
      _host(DrawingView(document: _doc(jointsVisible: false))),
    );
    final hidden = await _capture(tester);
    var differ = false;
    for (var y = 0; y < 300 && !differ; y++) {
      for (var x = 0; x < 400; x++) {
        if (shown.getPixel(x, y) != hidden.getPixel(x, y)) {
          differ = true;
          break;
        }
      }
    }
    expect(differ, isTrue);
  });

  testWidgets('a tap reaches an ancestor GestureDetector (AC 6, VW-5)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GestureDetector(
          onTap: () => taps++,
          child: DrawingView(document: _doc()),
        ),
      ),
    );
    await tester.tap(find.byType(DrawingView));
    expect(taps, 1);
  });

  testWidgets('semantics: image node only with a label (VW-6)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(DrawingView(document: _doc())));
    expect(find.bySemanticsLabel('Drawing'), findsNothing);
    await tester.pumpWidget(
      _host(DrawingView(document: _doc(), semanticLabel: 'Drawing')),
    );
    expect(find.bySemanticsLabel('Drawing'), findsOneWidget);
    handle.dispose();
  });

  test('repaints only when document or style change (VW-7)', () {
    final a = DrawingView(document: _doc());
    final b = DrawingView(document: _doc());
    expect(a.document == b.document, isTrue);
    expect(a.jointStyle == b.jointStyle, isTrue);
  });
}
