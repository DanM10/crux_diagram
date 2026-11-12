import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../export/jpeg_export.dart';
import '../geometry/anchors.dart' as anchors show anchorsOf;
import '../geometry/anchors.dart' show Anchor;
import '../geometry/grid.dart';
import '../geometry/joint_geometry.dart';
import '../geometry/resize.dart';
import '../geometry/rotation.dart';
import '../geometry/transforms.dart';
import '../model/drawing_document.dart';
import '../model/id_generator.dart';
import '../model/joint.dart';
import '../model/joint_names.dart';
import '../model/shape_element.dart';
import '../model/shape_type.dart';
import '../model/shape_type_defaults.dart';
import 'document_history.dart';
import 'drawing_editor_config.dart';
import 'drawing_tool.dart';

/// Holds the document being edited, the selection and the undo history.
///
/// Every edit replaces [document] with a new immutable instance and notifies
/// listeners. One-shot actions add one undo entry each; drag, resize and
/// rotate gestures add one entry when the gesture ends.
class DrawingEditorController extends ChangeNotifier {
  /// Creates a controller editing [initial], or an empty document with
  /// [config]'s canvas size.
  ///
  /// [idGenerator] and [jointIdGenerator] produce ids for new shapes and
  /// joints; the defaults combine a timestamp with a counter.
  DrawingEditorController({
    DrawingDocument? initial,
    this.config = const DrawingEditorConfig(),
    String Function()? idGenerator,
    String Function()? jointIdGenerator,
  }) : _document = initial ?? DrawingDocument(canvasSize: config.canvasSize),
       _nextId = idGenerator ?? defaultIdGenerator(prefix: 's'),
       _nextJointId = jointIdGenerator ?? defaultIdGenerator(prefix: 'j'),
       _history = DocumentHistory(limit: config.historyLimit) {
    _cleanBaseline = _document;
  }

  /// Distance, in canvas units, between cascaded and duplicated shapes.
  static const double cascadeOffset = 20;

  /// Editor settings.
  final DrawingEditorConfig config;

  final String Function() _nextId;
  final String Function() _nextJointId;
  final DocumentHistory _history;
  DrawingDocument _document;
  late DrawingDocument _cleanBaseline;
  String? _selectedId;
  String? _selectedJointId;
  DrawingTool _tool = DrawingTool.select;

  /// Document at the start of the running gesture, or null.
  DrawingDocument? _gestureStart;

  /// The current document.
  DrawingDocument get document => _document;

  /// Id of the selected shape, or null. A shape and a joint are never
  /// selected at the same time.
  String? get selectedId => _selectedId;

  /// The selected joint, or null.
  Joint? get selectedJoint => _jointById(_selectedJointId);

  /// The active tool. Setting it notifies listeners.
  DrawingTool get tool => _tool;

  set tool(DrawingTool value) {
    if (_tool == value) return;
    _tool = value;
    notifyListeners();
  }

  /// The anchors of the shape with [shapeId], in canvas coordinates.
  ///
  /// Throws [ArgumentError] when no such shape exists.
  List<Anchor> anchorsOf(String shapeId) =>
      anchors.anchorsOf(_shapeOrThrow(shapeId));

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

  /// Adds a joint on anchor [anchorId] of shape [shapeId] and selects it.
  ///
  /// [name] is trimmed and limited to [DrawingEditorConfig.jointNameMaxLength];
  /// when omitted, the next auto name is used (`J1`, `J2`, ...). The label
  /// starts at the default offset, pointing away from the shape center.
  ///
  /// Throws [ArgumentError] when the shape or anchor does not exist, the
  /// anchor already has a joint, or [name] is blank.
  Joint addJoint(String shapeId, String anchorId, {String? name}) {
    final joint = _newJoint(shapeId, anchorId, name: name);
    _commit(
      _document.copyWith(joints: [..._document.joints, joint]),
      selectJoint: joint.id,
    );
    return joint;
  }

  /// Renames the joint with [jointId] to [name], trimmed and limited to
  /// [DrawingEditorConfig.jointNameMaxLength]. A blank [name] keeps the old
  /// name.
  ///
  /// Throws [ArgumentError] when no such joint exists.
  void renameJoint(String jointId, String name) {
    final joint = _jointOrThrow(jointId);
    final normalized = normalizeJointName(name, config.jointNameMaxLength);
    if (normalized == null || normalized == joint.name) return;
    _commit(_withJoint(joint.copyWith(name: normalized)));
  }

  /// Sets the label offset of the joint with [jointId], keeping the label
  /// center inside the canvas.
  ///
  /// Throws [ArgumentError] when no such joint exists.
  void moveJointLabel(String jointId, Offset labelOffset) {
    final joint = _jointOrThrow(jointId);
    final moved = joint.copyWith(
      labelOffset: clampLabelOffset(
        _anchorPosition(joint),
        labelOffset,
        _document.canvasSize,
      ),
    );
    if (moved == joint) return;
    _commit(_withJoint(moved));
  }

  /// Removes the joint with [jointId].
  ///
  /// Throws [ArgumentError] when no such joint exists.
  void removeJoint(String jointId) {
    _jointOrThrow(jointId);
    _commit(
      _document.copyWith(
        joints: [
          for (final j in _document.joints)
            if (j.id != jointId) j,
        ],
      ),
      selectJoint: _selectedJointId == jointId ? null : _keepSelection,
    );
  }

  /// Deletes the selected joint, or else the selected shape together with
  /// its joints.
  void deleteSelected() {
    final joint = selectedJoint;
    if (joint != null) {
      removeJoint(joint.id);
      return;
    }
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

  /// The document with [shapes], keeping the joints whose shape survives.
  DrawingDocument _withShapes(List<ShapeElement> shapes) {
    final ids = {for (final shape in shapes) shape.id};
    return _document.copyWith(
      shapes: shapes,
      joints: [
        for (final joint in _document.joints)
          if (ids.contains(joint.shapeId)) joint,
      ],
    );
  }

  /// Applies a one-shot edit as a single history entry.
  void _commit(
    DrawingDocument next, {
    Object? select = _keepSelection,
    Object? selectJoint = _keepSelection,
  }) {
    _history.record(_document);
    _document = next;
    _applySelection(select, selectJoint);
    notifyListeners();
  }

  /// Applies a shape and/or joint selection; selecting one clears the other.
  void _applySelection(Object? select, Object? selectJoint) {
    if (select != _keepSelection) {
      _selectedId = select as String?;
      if (_selectedId != null) _selectedJointId = null;
    }
    if (selectJoint != _keepSelection) {
      _selectedJointId = selectJoint as String?;
      if (_selectedJointId != null) _selectedId = null;
    }
  }

  Joint _newJoint(String shapeId, String anchorId, {String? name}) {
    final shape = _shapeOrThrow(shapeId);
    final anchor = anchors
        .anchorsOf(shape)
        .where((a) => a.id == anchorId)
        .firstOrNull;
    if (anchor == null) {
      throw ArgumentError.value(
        anchorId,
        'anchorId',
        'Not an anchor of a ${shape.type.name}',
      );
    }
    if (_document.joints.any(
      (j) => j.shapeId == shapeId && j.anchorId == anchorId,
    )) {
      throw ArgumentError.value(
        anchorId,
        'anchorId',
        'Shape "$shapeId" already has a joint on this anchor',
      );
    }
    final String resolvedName;
    if (name == null) {
      resolvedName = nextJointName(
        config.jointNamePrefix,
        _document.joints.map((j) => j.name),
      );
    } else {
      resolvedName =
          normalizeJointName(name, config.jointNameMaxLength) ??
          (throw ArgumentError.value(name, 'name', 'Must not be blank'));
    }
    return Joint(
      id: _uniqueJointId(),
      shapeId: shapeId,
      anchorId: anchorId,
      name: resolvedName,
      labelOffset: defaultLabelOffset(shape.center, anchor.position),
    );
  }

  ShapeElement _shapeOrThrow(String shapeId) {
    for (final shape in _document.shapes) {
      if (shape.id == shapeId) return shape;
    }
    throw ArgumentError.value(shapeId, 'shapeId', 'No such shape');
  }

  Joint? _jointById(String? jointId) {
    if (jointId == null) return null;
    for (final joint in _document.joints) {
      if (joint.id == jointId) return joint;
    }
    return null;
  }

  Joint _jointOrThrow(String jointId) =>
      _jointById(jointId) ??
      (throw ArgumentError.value(jointId, 'jointId', 'No such joint'));

  /// Canvas position of [joint]'s anchor in the current document.
  Offset _anchorPosition(Joint joint) => anchors
      .anchorsOf(_shapeOrThrow(joint.shapeId))
      .firstWhere((a) => a.id == joint.anchorId)
      .position;

  DrawingDocument _withJoint(Joint updated) => _document.copyWith(
    joints: [
      for (final j in _document.joints) j.id == updated.id ? updated : j,
    ],
  );

  String _uniqueJointId() {
    final taken = {for (final j in _document.joints) j.id};
    var id = _nextJointId();
    while (taken.contains(id)) {
      id = _nextJointId();
    }
    return id;
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
    if (selectedJoint == null) _selectedJointId = null;
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
  /// Clears any joint selection.
  void select(String? id) {
    if (_selectedId == id && _selectedJointId == null) return;
    _selectedId = id;
    _selectedJointId = null;
    _notify();
  }

  /// Selects the joint with [id], or clears the selection with null.
  /// Clears any shape selection.
  void selectJoint(String? id) {
    if (_selectedJointId == id && _selectedId == null) return;
    _selectedJointId = id;
    _selectedId = null;
    _notify();
  }

  /// Starts creating a joint on [anchorId] of [shapeId] (spec 02, JT-2): the
  /// joint appears with the next auto name and is selected, but nothing is
  /// recorded until [confirmJointCreation].
  ///
  /// Throws [ArgumentError] like [DrawingEditorController.addJoint].
  Joint beginJointCreation(String shapeId, String anchorId) {
    final joint = _newJoint(shapeId, anchorId);
    beginGesture();
    _document = _document.copyWith(joints: [..._document.joints, joint]);
    _selectedJointId = joint.id;
    _selectedId = null;
    _notify();
    return joint;
  }

  /// Finishes [beginJointCreation] with [name] as one history entry. A blank
  /// [name] cancels the creation (spec 02, NM-1).
  void confirmJointCreation(String name) {
    final joint = selectedJoint;
    final normalized = normalizeJointName(name, config.jointNameMaxLength);
    if (joint == null || normalized == null) {
      cancelGesture();
      _dropStaleSelection();
      _notify();
      return;
    }
    _document = _withJoint(joint.copyWith(name: normalized));
    endGesture();
    _notify();
  }

  /// Moves the selected joint's label by [delta] from its offset at gesture
  /// start, keeping the label center inside the canvas (spec 02, AW-4).
  void dragSelectedJointLabelBy(Offset delta) {
    final start = _gestureStart;
    final id = _selectedJointId;
    if (start == null || id == null) return;
    final startJoint = start.joints.where((j) => j.id == id).firstOrNull;
    final current = _jointById(id);
    if (startJoint == null || current == null) return;
    _document = _withJoint(
      current.copyWith(
        labelOffset: clampLabelOffset(
          _anchorPosition(current),
          startJoint.labelOffset + delta,
          _document.canvasSize,
        ),
      ),
    );
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
