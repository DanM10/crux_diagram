import '../model/drawing_document.dart';

/// Snapshot-based undo/redo stacks with a size limit.
class DocumentHistory {
  /// Creates an empty history keeping at most [limit] undo entries.
  DocumentHistory({required this.limit});

  /// Maximum number of undo entries.
  final int limit;

  final List<DrawingDocument> _undo = [];
  final List<DrawingDocument> _redo = [];

  /// Whether [undo] can return a document.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether [redo] can return a document.
  bool get canRedo => _redo.isNotEmpty;

  /// Records [previous] as the state before a new edit and clears redo.
  void record(DrawingDocument previous) {
    _undo.add(previous);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  /// Returns the document to restore, storing [current] for redo.
  DrawingDocument undo(DrawingDocument current) {
    _redo.add(current);
    return _undo.removeLast();
  }

  /// Returns the document to restore, storing [current] for undo.
  DrawingDocument redo(DrawingDocument current) {
    _undo.add(current);
    return _redo.removeLast();
  }
}
