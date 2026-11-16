import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';

/// Settings shared by the editor and the `DrawingView`, so joints look the
/// same everywhere.
const exampleConfig = DrawingEditorConfig(
  shapeStyle: ShapeStyle(stroke: Color(0xFF1565C0), strokeWidth: 3),
  jointStyle: JointStyle(color: Color(0xFF2E7D32)),
  imageFormat: ImageFormat.png,
  transparentBackground: true,
  jointNameSuggestions: ['Elbow', 'Knee', 'Shoulder', 'Wrist'],
);

void main() => runApp(const ExampleApp());

/// Demo app: draw shapes and named joints, export them as an image plus JSON,
/// and reopen the saved JSON.
class ExampleApp extends StatelessWidget {
  /// Creates the demo app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'soft_drawer_service',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const ExampleHome(),
    );
  }
}

/// Shows the last saved drawing and opens the editor.
class ExampleHome extends StatefulWidget {
  /// Creates the home screen.
  const ExampleHome({super.key});

  /// Key of the image preview, for tests.
  static const Key previewKey = ValueKey('example.preview');

  /// Key of the `DrawingView` preview, for tests.
  static const Key viewKey = ValueKey('example.view');

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  Uint8List? _image;
  String? _json;

  Future<void> _openEditor({String? initialJson}) async {
    final result = await Navigator.of(context).push<DrawingResult>(
      MaterialPageRoute(
        builder: (_) =>
            DrawingEditorPage(initialJson: initialJson, config: exampleConfig),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _image = result.image;
      _json = result.json;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final json = _json;
    return Scaffold(
      appBar: AppBar(title: const Text('soft_drawer_service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New drawing'),
                  onPressed: () => _openEditor(),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Reopen drawing'),
                  onPressed: json == null
                      ? null
                      : () => _openEditor(initialJson: json),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (image == null)
              const Text('No drawing yet.')
            else ...[
              Text(
                'Exported image',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(border: Border.all()),
                child: Image.memory(image, key: ExampleHome.previewKey),
              ),
              const SizedBox(height: 24),
              Text(
                'Viewer (DrawingView)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(border: Border.all()),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: DrawingView(
                    key: ExampleHome.viewKey,
                    document: DrawingDocument.fromJson(json!),
                    jointStyle: exampleConfig.jointStyle,
                    semanticLabel: 'Saved drawing',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Saved JSON',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(
                json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
