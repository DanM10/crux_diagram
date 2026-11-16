import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service_example/main.dart';

void main() {
  testWidgets('home starts empty; reopen is disabled until a drawing is '
      'saved', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('No drawing yet.'), findsOneWidget);
    final reopen = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reopen drawing'),
    );
    expect(reopen.onPressed, isNull);
  });

  testWidgets('new drawing, add a shape, Done shows the JPEG and JSON, and '
      'reopen restores the shape', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('New drawing'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawingEditorPage), findsOneWidget);

    await tester.tap(find.byTooltip('Add square'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      // Export renders and encodes in an isolate; give it real time.
      for (
        var i = 0;
        i < 50 && find.byType(DrawingEditorPage).evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(DrawingEditorPage), findsNothing);
    expect(find.byKey(ExampleHome.previewKey), findsOneWidget);
    expect(find.textContaining('"schemaVersion":3'), findsOneWidget);

    await tester.tap(find.text('Reopen drawing'));
    await tester.pumpAndSettle();
    final editor = tester.widget<DrawingEditor>(find.byType(DrawingEditor));
    expect(editor.controller.document.shapes, hasLength(1));
  });
}
