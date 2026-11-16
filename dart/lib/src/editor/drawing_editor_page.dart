import 'package:flutter/material.dart';

import '../model/drawing_document.dart';
import 'drawing_editor.dart';
import 'drawing_editor_config.dart';
import 'drawing_editor_controller.dart';
import 'drawing_editor_labels.dart';
import 'drawing_result.dart';

/// Full-screen editor page.
///
/// Pops a [DrawingResult] when the user confirms, and `null` when they
/// cancel. Leaving with unsaved changes (cancel or system back) asks for
/// confirmation first.
///
/// When [initialJson] cannot be opened, the page shows
/// [DrawingEditorLabels.invalidDrawing] and a [DrawingEditorLabels.close]
/// button that pops `null`, as if the user cancelled; no editor is shown, so
/// the saved drawing is never replaced (spec 05, JX-2). Check the JSON
/// beforehand with [DrawingDocument.validate].
class DrawingEditorPage extends StatefulWidget {
  /// Creates the page. [initialJson] reopens a drawing saved from a previous
  /// [DrawingResult]; an invalid one shows an error instead of the editor.
  const DrawingEditorPage({
    super.key,
    this.initialJson,
    this.config = const DrawingEditorConfig(),
    this.labels = const DrawingEditorLabels(),
  });

  /// JSON of a drawing to reopen, or null for a new drawing.
  final String? initialJson;

  /// Editor settings.
  final DrawingEditorConfig config;

  /// User-visible strings.
  final DrawingEditorLabels labels;

  @override
  State<DrawingEditorPage> createState() => _DrawingEditorPageState();
}

class _DrawingEditorPageState extends State<DrawingEditorPage> {
  /// Null when [DrawingEditorPage.initialJson] could not be opened.
  DrawingEditorController? _controller;
  bool _exporting = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final json = widget.initialJson;
    if (json != null && DrawingDocument.validate(json) != null) return;
    _controller = DrawingEditorController(
      initial: json == null ? null : DrawingDocument.fromJson(json),
      config: widget.config,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final controller = _controller!;
    setState(() => _exporting = true);
    try {
      final image = await controller.exportImage();
      final json = controller.toJson();
      controller.markClean();
      if (!mounted) return;
      _leaving = true;
      Navigator.of(context).pop(
        DrawingResult(
          image: image,
          format: controller.config.imageFormat,
          json: json,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.labels.exportFailed)));
    }
  }

  Future<void> _confirmDiscard() async {
    final labels = widget.labels;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(labels.discardChangesTitle),
        content: Text(labels.discardChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(labels.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(labels.discard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final controller = _controller;
    if (controller == null) return _InvalidDrawing(labels: labels);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => PopScope<Object?>(
        canPop: _leaving || !controller.isDirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: child!,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: labels.cancel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            TextButton(
              onPressed: _exporting ? null : _confirm,
              child: Text(labels.done),
            ),
          ],
        ),
        body: DrawingEditor(controller: controller, labels: labels),
      ),
    );
  }
}

/// Shown instead of the editor when the initial JSON is invalid (JX-2).
class _InvalidDrawing extends StatelessWidget {
  const _InvalidDrawing({required this.labels});

  final DrawingEditorLabels labels;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(labels.invalidDrawing, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(labels.close),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
