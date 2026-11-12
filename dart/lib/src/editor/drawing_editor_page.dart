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
class DrawingEditorPage extends StatefulWidget {
  /// Creates the page. [initialJson] reopens a drawing saved from a previous
  /// [DrawingResult]; it throws `DrawingFormatException` if it is invalid.
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
  late final DrawingEditorController _controller;
  bool _exporting = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final json = widget.initialJson;
    _controller = DrawingEditorController(
      initial: json == null ? null : DrawingDocument.fromJson(json),
      config: widget.config,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _exporting = true);
    try {
      final jpeg = await _controller.exportJpeg();
      final json = _controller.toJson();
      _controller.markClean();
      if (!mounted) return;
      _leaving = true;
      Navigator.of(context).pop(DrawingResult(jpeg: jpeg, json: json));
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
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => PopScope<Object?>(
        canPop: _leaving || !_controller.isDirty,
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
        body: DrawingEditor(controller: _controller, labels: labels),
      ),
    );
  }
}
