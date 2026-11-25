import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:crux_diagram/crux_diagram.dart';

/// Opens the page from a launcher and records what it pops.
class _Launcher extends StatefulWidget {
  const _Launcher({this.initialJson, this.format = ImageFormat.jpeg});

  final String? initialJson;
  final ImageFormat format;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  DrawingResult? result;
  bool popped = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async {
          final value = await Navigator.of(context).push<DrawingResult>(
            MaterialPageRoute(
              builder: (_) => DrawingEditorPage(
                initialJson: widget.initialJson,
                config: DrawingEditorConfig(
                  canvasSize: const Size(400, 300),
                  imageFormat: widget.format,
                ),
              ),
            ),
          );
          setState(() {
            result = value;
            popped = true;
          });
        },
        child: const Text('open'),
      ),
    ),
  );
}

Future<_LauncherState> _open(
  WidgetTester tester, {
  String? initialJson,
  ImageFormat format = ImageFormat.jpeg,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _Launcher(initialJson: initialJson, format: format),
    ),
  );
  // The launcher goes offstage once the page is pushed, so read it first.
  final launcher = tester.state<_LauncherState>(find.byType(_Launcher));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return launcher;
}

Future<void> _settleAsync(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Done returns the configured format (spec 06, AC 8)', (
    tester,
  ) async {
    final jpeg = await _open(tester);
    await tester.tap(find.text('Done'));
    await _settleAsync(tester);
    expect(jpeg.result!.format, ImageFormat.jpeg);
    expect(jpeg.result!.image.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
  });

  testWidgets('Done returns a PNG with imageFormat png (spec 06, AC 8)', (
    tester,
  ) async {
    final launcher = await _open(tester, format: ImageFormat.png);
    await tester.tap(find.text('Done'));
    await _settleAsync(tester);
    expect(launcher.result!.format, ImageFormat.png);
    expect(launcher.result!.image.sublist(0, 8), [
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

  testWidgets('Done pops a DrawingResult with a JPEG and the JSON', (
    tester,
  ) async {
    final launcher = await _open(tester);
    await tester.tap(find.byTooltip('Add square'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await _settleAsync(tester);

    expect(launcher.popped, isTrue);
    final result = launcher.result!;
    final image = img.decodeJpg(result.image)!;
    expect(image.width, 400);
    expect(image.height, 300);
    final document = DrawingDocument.fromJson(result.json);
    expect(document.shapes.single.type, ShapeType.square);
  });

  testWidgets('Done also returns the geometry of the saved JSON (spec 06)', (
    tester,
  ) async {
    final launcher = await _open(tester);
    await tester.tap(find.byTooltip('Add square'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await _settleAsync(tester);

    final result = launcher.result!;
    final document = DrawingDocument.fromJson(result.json);
    expect(result.geometry.toJson(), computeGeometry(document).toJson());
    expect(result.geometry.shapes.single.id, document.shapes.single.id);
  });

  testWidgets('Cancel with no changes pops null without asking', (
    tester,
  ) async {
    final launcher = await _open(tester);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(launcher.popped, isTrue);
    expect(launcher.result, isNull);
  });

  testWidgets(
    'leaving with changes asks; Keep editing stays, Discard pops null (AC 10)',
    (tester) async {
      final launcher = await _open(tester);
      await tester.tap(find.byTooltip('Add circle'));
      await tester.pump();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(launcher.popped, isFalse);
      expect(find.byType(DrawingEditorPage), findsOneWidget);

      // System back button goes through the same confirmation.
      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(launcher.popped, isTrue);
      expect(launcher.result, isNull);
    },
  );

  testWidgets('initialJson opens the saved drawing and starts clean', (
    tester,
  ) async {
    final json = DrawingDocument(
      canvasSize: const Size(400, 300),
      shapes: [
        ShapeElement(
          id: 'saved',
          type: ShapeType.rectangle,
          center: const Offset(200, 150),
          size: const Size(240, 140),
        ),
      ],
    ).toJson();
    final launcher = await _open(tester, initialJson: json);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(launcher.popped, isTrue);
  });

  group('invalid initialJson (spec 05, JX-2, AC 7)', () {
    testWidgets('shows the message and Close, with no editor', (tester) async {
      final launcher = await _open(tester, initialJson: '{not json');
      expect(tester.takeException(), isNull);
      expect(find.text('This drawing could not be opened.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byType(DrawingEditor), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(launcher.popped, isFalse);
    });

    testWidgets('Close pops a null result without asking', (tester) async {
      final launcher = await _open(
        tester,
        initialJson: jsonEncode({'schemaVersion': 99}),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(DrawingEditorPage), findsNothing);
      expect(launcher.popped, isTrue);
      expect(launcher.result, isNull);
    });

    testWidgets('system back also pops a null result', (tester) async {
      final launcher = await _open(tester, initialJson: '[]');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(launcher.popped, isTrue);
      expect(launcher.result, isNull);
    });

    testWidgets('valid and null initialJson still open the editor', (
      tester,
    ) async {
      for (final json in [null, DrawingDocument().toJson()]) {
        await _open(tester, initialJson: json);
        expect(find.byType(DrawingEditor), findsOneWidget);
        expect(find.text('This drawing could not be opened.'), findsNothing);
        expect(find.text('Close'), findsNothing);
        await tester.tap(find.byTooltip('Cancel'));
        await tester.pumpAndSettle();
      }
    });
  });
}
