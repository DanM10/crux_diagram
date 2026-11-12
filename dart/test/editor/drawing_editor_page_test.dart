import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soft_drawer_service/soft_drawer_service.dart';

/// Opens the page from a launcher and records what it pops.
class _Launcher extends StatefulWidget {
  const _Launcher({this.initialJson});

  final String? initialJson;

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
                config: const DrawingEditorConfig(canvasSize: Size(400, 300)),
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

Future<_LauncherState> _open(WidgetTester tester, {String? initialJson}) async {
  await tester.pumpWidget(
    MaterialApp(home: _Launcher(initialJson: initialJson)),
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
    final image = img.decodeJpg(result.jpeg)!;
    expect(image.width, 400);
    expect(image.height, 300);
    final document = DrawingDocument.fromJson(result.json);
    expect(document.shapes.single.type, ShapeType.square);
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
}
