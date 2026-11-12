import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../export/jpeg_export.dart';
import '../geometry/grid.dart';
import '../geometry/resize.dart';
import '../geometry/rotation.dart';
import '../geometry/transforms.dart';
import '../model/drawing_document.dart';
import '../model/id_generator.dart';
import '../model/shape_element.dart';
import '../model/shape_type.dart';
import '../model/shape_type_defaults.dart';
import 'document_history.dart';
import 'drawing_editor_config.dart';

/// Holds the document being edited, the selection and the undo history.
///
/// Every edit replaces [document] with a new immutable instance and notifies
/// listeners. One-shot actions add one undo entry each; drag, resize and
/// rotate gestures add one entry when the gesture ends.
class DrawingEditorController extends ChangeNotifier {
  /// Creates a controller editing [initial], or an empty document with
  /// [config]'s canvas size.
  ///
  /// [idGenerator] produces ids for new shapes; the default combines a
  /// timestamp with a counter.
  DrawingEditorController({
    DrawingDocument? initial,
    this.config = const DrawingEditorConfig(),
    String Function()? idGenerator,
  }) : _document = initial ?? DrawingDocument(canvasSize: config.canvasSize),
       _nextId = idGenerator ?? defaultIdGenerator(prefix: 's'),
       _history = DocumentHistory(limit: config.historyLimit) {
    _cleanBaseline = _document;
  }

  /// Distance, in canvas units, between cascaded and duplicated shapes.
  static const double cascadeOffset = 20;

  /// Editor settings.
  final DrawingEditorConfig config;

  final String Function() _nextId;
  final DocumentHistory _history;
  DrawingDocument _document;
  late DrawingDocument _cleanBaseline;
  String? _selectedId;

  /// Document at the start of the running gesture, or null.
  DrawingDocument? _gestureStart;

  /// The current document.
  DrawingDocument get document => _document;

  /// Id of the selected shape, or null.
  String? get selectedId => _selectedId;

  /// Whether [undo] has an entry to restore.
  bool get canUndo => _history.canUndo;

  /// Whether [redo] has an entry to restore.
  bool get canRedo => _history.canRedo;

  /// Whether the document differs from the clean baseline: the initial
  /// document, or the document at the last [markClean] call.
  bool get isDirty => _document != _cleanBaseline;

  /// Makes the current document the clean baseline.
  void markClean() {
    _cleanBaseline = _document;
    notifyListeners();
  }

  /// Adds a shape of [type] with its default size at the canvas center (or
  /// the next free cascade position), on top of the stack, and selects it.
  void addShape(ShapeType type) {
    final shape = ShapeElement(
      id: _uniqueId(),
      type: type,
      center: _cascadePosition(type),
      size: type.defaultSize,
    );
    _commit(_withShapes([..._document.shapes, shape]), select: shape.id);
  }

  /// Deletes the selected shape.
  void deleteSelected() {
    final selected = _selected;
    if (selected == null) return;
    _commit(
      _withShapes([
        for (final s in _document.shapes)
          if (s.id != selected.id) s,
      ]),
      select: null,
    );
  }

  /// Duplicates the selected shape with a new id, offset diagonally by
  /// [cascadeOffset], on top of the stack, and selects the copy.
  void duplicateSelected() {
    final selected = _selected;
    if (selected == null) return;
    final copy = selected.copyWith(
      id: _uniqueId(),
      center: clampToCanvas(
        selected.center + const Offset(cascadeOffset, cascadeOffset),
        _document.canvasSize,
      ),
    );
    _commit(_withShapes([..._document.shapes, copy]), select: copy.id);
  }

  /// Rotates the selected shape clockwise by [radians].
  void rotateSelectedBy(double radians) {
    final selected = _selected;
    if (selected == null) return;
    _replaceSelected(selected.copyWith(rotation: selected.rotation + radians));
  }

  /// Moves the selected shape to the top of the stack.
  void bringToFront() {
    final selected = _selected;
    if (selected == null) return;
    _commit(
      _withShapes([
        for (final s in _document.shapes)
          if (s.id != selected.id) s,
        selected,
      ]),
    );
  }

  /// Moves the selected shape to the bottom of the stack.
  void sendToBack() {
    final selected = _selected;
    if (selected == null) return;
    _commit(
      _withShapes([
        selected,
        for (final s in _document.shapes)
          if (s.id != selected.id) s,
      ]),
    );
  }

  /// Restores the previous document.
  void undo() {
    if (!_history.canUndo) return;
    _cancelGestureSilently();
    _document = _history.undo(_document);
    _dropStaleSelection();
    notifyListeners();
  }

  /// Re-applies the last undone document.
  void redo() {
    if (!_history.canRedo) return;
    _cancelGestureSilently();
    _document = _history.redo(_document);
    _dropStaleSelection();
    notifyListeners();
  }

  /// Encodes the current document as JSON.
  String toJson() => _document.toJson();

  /// Renders the current document as JPEG at `canvasSize × pixelRatio`.
  ///
  /// [quality] defaults to [DrawingEditorConfig.jpegQuality]. Throws
  /// [ArgumentError] when the image would exceed
  /// [DrawingEditorConfig.maxExportPixels] or the arguments are out of range.
  Future<Uint8List> exportJpeg({double pixelRatio = 1.0, int? quality}) =>
      exportDocumentJpeg(
        _document,
        pixelRatio: pixelRatio,
        quality: quality ?? config.jpegQuality,
        maxPixels: config.maxExportPixels,
      );

  ShapeElement? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final shape in _document.shapes) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  DrawingDocument _withShapes(List<ShapeElement> shapes) =>
      DrawingDocument(canvasSize: _document.canvasSize, shapes: shapes);

  /// Applies a one-shot edit as a single history entry.
  void _commit(DrawingDocument next, {Object? select = _keepSelection}) {
    _history.record(_document);
    _document = next;
    if (select != _keepSelection) _selectedId = select as String?;
    notifyListeners();
  }

  void _replaceSelected(ShapeElement updated) {
    _commit(
      _withShapes([
        for (final s in _document.shapes) s.id == updated.id ? updated : s,
      ]),
    );
  }

  String _uniqueId() {
    final taken = {for (final s in _document.shapes) s.id};
    var id = _nextId();
    while (taken.contains(id)) {
      id = _nextId();
    }
    return id;
  }

  /// FR-5: the canvas center, or the first diagonal cascade step not taken
  /// by a shape of the same type; wraps back to the center when the next
  /// step would leave the canvas.
  Offset _cascadePosition(ShapeType type) {
    final canvas = _document.canvasSize;
    final start = canvas.center(Offset.zero);
    bool taken(Offset position) =>
        _document.shapes.any((s) => s.type == type && s.center == position);
    var position = start;
    while (taken(position)) {
      position += const Offset(cascadeOffset, cascadeOffset);
      if (position.dx > canvas.width || position.dy > canvas.height) {
        return start;
      }
    }
    return position;
  }

  /// Lets the same-library gesture extension notify listeners, since
  /// [notifyListeners] is protected.
  void _notify() => notifyListeners();

  void _dropStaleSelection() {
    if (_selected == null) _selectedId = null;
  }

  void _cancelGestureSilently() {
    if (_gestureStart != null) {
      _document = _gestureStart!;
      _gestureStart = null;
    }
  }
}

const Object _keepSelection = Object();

/// Gesture and selection operations used by the editor widgets.
///
/// Not exported from the public library.
extension DrawingEditorGestures on DrawingEditorController {
  /// The selected shape, or null.
  ShapeElement? get selectedShape => _selected;

  /// Selects the shape with [id], or clears the selection with null.
  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    _notify();
  }

  /// Starts a gesture. Changes until [endGesture] form one history entry.
  void beginGesture() {
    _gestureStart ??= _document;
  }

  /// Moves the selected shape by [delta] from its position at gesture start,
  /// snapping the center to the grid (FR-9) and clamping it to the canvas
  /// (FR-10).
  void moveSelectedBy(Offset delta) {
    final start = _gestureShape;
    if (start == null) return;
    var center = start.center + delta;
    final grid = config.gridSize;
    if (grid != null) center = snapPointToGrid(center, grid);
    center = clampToCanvas(center, _document.canvasSize);
    _preview(start.copyWith(center: center));
  }

  /// Resizes the selected shape by dragging [handle] to [pointer]
  /// (FR-11 to FR-14).
  void resizeSelected(ResizeHandle handle, Offset pointer) {
    final start = _gestureShape;
    if (start == null) return;
    final grid = config.gridSize;
    _preview(
      resizeShape(
        start,
        handle,
        pointer,
        limits: SizeLimits.forCanvas(_document.canvasSize, gridSize: grid),
        gridSize: grid,
      ),
    );
  }

  /// Rotates the selected shape so its rotation handle points at [pointer],
  /// with soft snapping (FR-15, FR-16).
  void rotateSelectedToward(Offset pointer) {
    final start = _gestureShape;
    if (start == null) return;
    final angle = softSnapAngle(
      rotationFromPointer(start.center, pointer),
      config.rotationSnapStep,
      config.rotationSnapTolerance,
    );
    _preview(start.copyWith(rotation: angle));
  }

  /// Ends the gesture, recording one history entry if anything changed.
  void endGesture() {
    final start = _gestureStart;
    if (start == null) return;
    _gestureStart = null;
    if (start != _document) {
      _history.record(start);
      _notify();
    }
  }

  /// Aborts the gesture and restores the document from its start.
  void cancelGesture() {
    if (_gestureStart == null) return;
    _cancelGestureSilently();
    _notify();
  }

  ShapeElement? get _gestureShape {
    final start = _gestureStart;
    final id = _selectedId;
    if (start == null || id == null) return null;
    for (final shape in start.shapes) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  void _preview(ShapeElement updated) {
    _document = _withShapes([
      for (final s in _document.shapes) s.id == updated.id ? updated : s,
    ]);
    _notify();
  }
}
