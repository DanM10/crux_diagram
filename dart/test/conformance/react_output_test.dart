import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';

/// Cross test (REA-O2, spec 05 section 7): a document saved by the React editor opens in
/// Flutter. The file is written by the React browser flow (`js/react/e2e/flow.spec.ts`, run
/// with `cd js/react && npm run e2e`); without it this test is skipped, so the Dart suite
/// does not depend on a browser.
final File _saved = File('../js/react/e2e/output/react-saved.json');

void main() {
  test(
    'a document saved by the React editor opens in Flutter',
    () {
      final doc = DrawingDocument.fromJson(_saved.readAsStringSync());
      expect(doc.shapes, hasLength(2));
      expect(doc.groups, hasLength(1));
      expect(doc.joints.single.name, 'A1');
      // Saving it again and reading it back keeps the same content.
      final again = DrawingDocument.fromJson(doc.toJson());
      expect(again.shapes.map((s) => s.id), doc.shapes.map((s) => s.id));
    },
    skip: _saved.existsSync()
        ? false
        : 'run the React browser flow first (cd js/react && npm run e2e)',
  );
}
