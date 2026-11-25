import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux_diagram/crux_diagram.dart';

import 'geometry_cases.dart';
import 'drawing_geometry_cases.dart';

/// Shared-format conformance (spec 02, section 15): every fixture under
/// `fixtures/` (at the monorepo root) must behave as its folder says. The same fixtures are run by
/// the TypeScript implementation.
const double _tolerance = 1e-6;

/// The fixtures live at the monorepo root, shared with the other packages.
final Directory _fixtures = Directory('../fixtures');

List<File> _files(String folder, {bool expected = false}) {
  final dir = Directory('${_fixtures.path}/$folder');
  if (!dir.existsSync()) return [];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .where((f) => f.path.endsWith('.expected.json') == expected)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String _name(File file) => file.uri.pathSegments.last;

/// Fails unless [actual] equals [expected], comparing numbers with
/// [_tolerance] and ignoring map key order.
void _expectClose(Object? actual, Object? expected, String path) {
  if (expected is num) {
    expect(actual, isA<num>(), reason: path);
    expect(
      (actual! as num).toDouble(),
      closeTo(expected.toDouble(), _tolerance),
      reason: path,
    );
  } else if (expected is List) {
    expect(actual, isA<List<Object?>>(), reason: path);
    final list = actual! as List;
    expect(list.length, expected.length, reason: '$path length');
    for (var i = 0; i < expected.length; i++) {
      _expectClose(list[i], expected[i], '$path[$i]');
    }
  } else if (expected is Map) {
    expect(actual, isA<Map<Object?, Object?>>(), reason: path);
    final map = actual! as Map;
    expect(map.keys.toSet(), expected.keys.toSet(), reason: '$path keys');
    for (final key in expected.keys) {
      _expectClose(map[key], expected[key], '$path.$key');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

void main() {
  test('the fixtures folder is present', () {
    expect(
      _fixtures.existsSync(),
      isTrue,
      reason: 'run `flutter test tool/generate_fixtures.dart` in dart/ first',
    );
  });

  group('valid documents are accepted (FMT-080)', () {
    for (final file in _files('valid')) {
      test(_name(file), () {
        expect(
          () => DrawingDocument.fromJson(file.readAsStringSync()),
          returnsNormally,
        );
      });
    }
  });

  group('invalid documents are rejected (FMT-081)', () {
    for (final file in _files('invalid')) {
      test(_name(file), () {
        expect(
          () => DrawingDocument.fromJson(file.readAsStringSync()),
          throwsA(isA<DrawingFormatException>()),
        );
      });
    }
  });

  group('round trip keeps the document (FMT-082)', () {
    for (final file in _files('roundtrip')) {
      test(_name(file), () {
        final saved =
            jsonDecode(
                  DrawingDocument.fromJson(file.readAsStringSync()).toJson(),
                )
                as Object?;
        final expectedFile = File(
          file.path.replaceFirst(RegExp(r'\.json$'), '.expected.json'),
        );
        final expected = jsonDecode(
          (expectedFile.existsSync() ? expectedFile : file).readAsStringSync(),
        );
        _expectClose(saved, expected, 'document');
      });
    }
  });

  group('geometry matches the expected results (FMT-083)', () {
    for (final file in _files('geometry')) {
      final fixture =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final function = fixture['function']! as String;
      for (final raw in fixture['cases']! as List) {
        final c = raw as Map<String, Object?>;
        test('$function: ${c['name']}', () {
          final actual = runGeometry(
            function,
            c['input']! as Map<String, Object?>,
          );
          _expectClose(actual, c['expected'], function);
        });
      }
    }
  });

  group(
    'drawing geometry matches the expected results (spec 06, GEO-O2, FLT-024)',
    () {
      for (final file in _files('drawing-geometry')) {
        test(_name(file), () {
          final fixture =
              jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
          expect(fixture['measurer'], 'ApproximateTextMeasurer');
          final document = fixtureDocument(
            fixture['document']! as Map<String, Object?>,
            valid: fixture['documentIsValid']! as bool,
          );
          final geometry = computeGeometry(
            document,
            measurer: const ApproximateTextMeasurer(),
          );
          _expectClose(geometry.toJson(), fixture['expected'], 'geometry');
          expect(validateGeometry(document, fixture['expected']), isEmpty);
        });
      }
    },
  );
}
