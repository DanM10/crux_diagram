import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../export/jpeg_export.dart';
import '../geometry/anchors.dart' as anchors show anchorsOf;
import '../geometry/anchor_snapping.dart';
import '../geometry/angles.dart';
import '../geometry/anchors.dart' show Anchor, AnchorKind, anchorPositionOf;
import '../geometry/grid.dart';
import '../geometry/joint_geometry.dart';
import '../geometry/resize.dart';
import '../geometry/rotation.dart';
import '../geometry/transforms.dart';
import '../model/drawing_document.dart';
import '../model/id_generator.dart';
import '../model/joint.dart';
import '../model/joint_label_size.dart';
import '../model/joint_names.dart';
import '../model/shape_element.dart';
import '../model/shape_group.dart';
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
  /// [idGenerator], [jointIdGenerator] and [groupIdGenerator] produce ids
  /// for new shapes, joints and groups; the defaults combine a timestamp
  /// with a counter.
  ///
  /// The groups of [initial] are normalized like after every edit: members
  /// that are not shapes of the document and repeated members are dropped,
  /// and so is a group left with fewer than two shapes (spec 05, MS-7).
  DrawingEditorController({
    DrawingDocument? initial,
    this.config = const DrawingEditorConfig(),
    String Function()? idGenerator,
    String Function()? jointIdGenerator,
    String Function()? groupIdGenerator,
  }) : _document = _normalizeGroups(
         initial ?? DrawingDocument(canvasSize: config.canvasSize),
       ),
       _nextId = idGenerator ?? defaultIdGenerator(prefix: 's'),
       _nextJointId = jointIdGenerator ?? defaultIdGenerator(prefix: 'j'),
       _nextGroupId = groupIdGenerator ?? defaultIdGenerator(prefix: 'g'),
       _history = DocumentHistory(limit: config.historyLimit),
       _gridVisible = config.showGrid && config.gridSize != null {
    if (config.gridMajorEvery < 2) {
      throw ArgumentError.value(
        config.gridMajorEvery,
        'config.gridMajorEvery',
        'Must be at least 2',
      );
    }
    _cleanBaseline = _document;
  }

  /// Distance, in canvas units, between cascaded and duplicated shapes.
  static const double cascadeOffset = 20;

  /// Editor settings.
  final DrawingEditorConfig config;

  final String Function() _nextId;
  final String Function() _nextJointId;
  final String Function() _nextGroupId;
  final DocumentHistory _history;
  DrawingDocument _document;
  late DrawingDocument _cleanBaseline;

  /// Ids of the selected shapes, in selection order. Always closed under
  /// groups: a selected group member brings its whole group (MS-6).
  final Set<String> _selection = <String>{};
  bool _selectionMode = false;
  String? _selectedJointId;
  DrawingTool _tool = DrawingTool.select;

  /// Document at the start of the running gesture, or null.
  DrawingDocument? _gestureStart;

  /// The two anchor positions of the active anchor snap, or empty.
  List<Offset> _snapHighlight = const [];

  /// Identity of the engaged rotation or anchor snap, or null
  /// (spec 03, HP-2).
  Object? _snapTarget;

  /// The current document.
  DrawingDocument get document => _document;

  bool _gridVisible;

  /// Whether the guide grid is drawn. It starts at
  /// [DrawingEditorConfig.showGrid] and is always `false` when
  /// [DrawingEditorConfig.gridSize] is null; setting it then has no effect.
  ///
  /// This is view state: it is not persisted, adds no undo entry and does
  /// not mark the document dirty. Grid snapping happens whether or not the
  /// grid is visible. The setter notifies listeners, so a host app that
  /// autosaves on every notification also fires on this view-only change.
  bool get gridVisible => _gridVisible;

  set gridVisible(bool value) {
    if (config.gridSize == null || _gridVisible == value) return;
    _gridVisible = value;
    notifyListeners();
  }

  /// Id of the selected shape when exactly one shape is selected, or null.
  /// It is null for a multi-selection (spec 05, section 6). A shape and a
  /// joint are never selected at the same time.
  String? get selectedId => _selection.length == 1 ? _selection.first : null;

  /// Ids of the selected shapes: empty, one or many (spec 05, section 6).
  ///
  /// Selecting a member of a group selects the whole group (MS-6). The set
  /// is an unmodifiable copy.
  Set<String> get selectedIds => Set.unmodifiable(_selection);

  /// Whether selection mode is on (spec 05, MS-1): taps on shapes add them
  /// to the selection or remove them, and a one-finger drag on empty
  /// canvas draws a selection rectangle (MS-3).
  ///
  /// This is view state: setting it notifies listeners, adds no undo entry
  /// and keeps the selection (MS-8). Turning it on clears a joint
  /// selection. Switching to [DrawingTool.joint] turns it off.
  bool get selectionMode => _selectionMode;

  set selectionMode(bool value) {
    if (_selectionMode == value) return;
    _selectionMode = value;
    if (value) _selectedJointId = null;
    notifyListeners();
  }

  /// Adds the shape with [shapeId] to the selection, or removes it when it
  /// is selected (spec 05, MS-1). A grouped shape adds or removes its whole
  /// group (MS-6). Clears any joint selection; adds no undo entry.
  ///
  /// Throws [ArgumentError] when no such shape exists.
  void toggleSelected(String shapeId) {
    _shapeOrThrow(shapeId);
    final members = _withGroupMates([shapeId]);
    if (_selection.contains(shapeId)) {
      _selection.removeAll(members);
    } else {
      _selection.addAll(members);
    }
    _selectedJointId = null;
    notifyListeners();
  }

  /// Adds the shapes with [shapeIds], and their groups, to the selection
  /// (spec 05, MS-3). Clears any joint selection; adds no undo entry.
  ///
  /// Throws [ArgumentError] when one of the shapes does not exist; the
  /// selection is then unchanged.
  void selectAll(Iterable<String> shapeIds) {
    final ids = shapeIds.toList();
    ids.forEach(_shapeOrThrow);
    _selection.addAll(_withGroupMates(ids));
    if (_selection.isNotEmpty) _selectedJointId = null;
    notifyListeners();
  }

  /// Turns the selected shapes into one group, as one history entry
  /// (spec 05, MS-6). Selected shapes that are already grouped are merged
  /// into the new group, since groups do not nest (decision 14).
  ///
  /// Does nothing with fewer than two selected shapes or when the selection
  /// is exactly one group.
  void groupSelected() {
    if (_selection.length < 2 || _selectedGroup != null) return;
    final members = [
      for (final shape in _document.shapes)
        if (_selection.contains(shape.id)) shape.id,
    ];
    _commit(
      _normalizeGroups(
        _document.copyWith(
          groups: [
            for (final group in _document.groups)
              if (!group.shapeIds.any(_selection.contains)) group,
            ShapeGroup(id: _uniqueGroupId(), shapeIds: members),
          ],
        ),
      ),
    );
  }

  /// Removes every group with a selected member, as one history entry
  /// (spec 05, MS-6). The shapes stay selected; afterwards each selects on
  /// its own. Does nothing when no selected shape is grouped.
  void ungroupSelected() {
    final kept = [
      for (final group in _document.groups)
        if (!group.shapeIds.any(_selection.contains)) group,
    ];
    if (kept.length == _document.groups.length) return;
    _commit(_document.copyWith(groups: kept));
  }

  /// The selected joint, or null.
  Joint? get selectedJoint => _jointById(_selectedJointId);

  /// The active tool. Setting it notifies listeners; switching to
  /// [DrawingTool.joint] clears the shape selection, since shapes cannot be
  /// moved, resized or rotated with it (spec 02, JT-1).
  DrawingTool get tool => _tool;

  set tool(DrawingTool value) {
    if (_tool == value) return;
    _tool = value;
    if (value == DrawingTool.joint) {
      _selection.clear();
      _selectionMode = false;
    }
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

  /// Adds a shape of [type] with its default size at [center] (default: the
  /// canvas center), on top of the stack, and selects it.
  ///
  /// The center is snapped to the grid when [DrawingEditorConfig.gridSize]
  /// is set. When a shape of the same type already sits there, the shape
  /// cascades by [cascadeOffset] down-right, or up-left once the next step
  /// would leave the canvas (spec 03, PL-2).
  void addShape(ShapeType type, {Offset? center}) {
    final shape = ShapeElement(
      id: _uniqueId(),
      type: type,
      center: _cascadePosition(type, center),
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
      _document.copyWith(
        joints: [..._document.joints, joint],
        jointsVisible: true,
      ),
      selectJoint: joint.id,
    );
    return joint;
  }

  /// Sets the size of every joint label as one history entry (spec 04,
  /// JS-4). Choosing the current size does nothing.
  void setJointLabelSize(JointLabelSize size) {
    if (_document.jointLabelSize == size) return;
    _commit(_document.copyWith(jointLabelSize: size));
  }

  /// Shows or hides every joint as one history entry (spec 04, JV-6).
  /// Hiding clears a joint selection and keeps a shape selection (JV-3);
  /// setting the current visibility does nothing.
  ///
  /// Hidden joints stay in the document. Adding a joint shows them again in
  /// the same history entry (JV-4).
  void setJointsVisible(bool visible) {
    if (_document.jointsVisible == visible) return;
    _commit(
      _document.copyWith(jointsVisible: visible),
      selectJoint: visible ? _keepSelection : null,
    );
  }

  /// Selects the joint with [jointId], showing hidden joints first (spec 05,
  /// FU-1).
  ///
  /// While joints are hidden, showing them and selecting the joint is one
  /// history entry; undoing it hides them again and clears the selection.
  /// While they are shown, this is [selectJoint] and records nothing.
  ///
  /// Throws [ArgumentError] when no such joint exists.
  void showJointsAndSelect(String jointId) {
    final joint = _jointOrThrow(jointId);
    if (_document.jointsVisible) {
      selectJoint(joint.id);
      return;
    }
    _commit(_document.copyWith(jointsVisible: true), selectJoint: joint.id);
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

  /// Deletes the selected joint, or else the selected shapes together with
  /// their joints, as one history entry. A group whose shapes are all
  /// deleted is deleted with them (spec 05, MS-5, MS-7).
  void deleteSelected() {
    final joint = selectedJoint;
    if (joint != null) {
      removeJoint(joint.id);
      return;
    }
    if (_selection.length > 1) {
      _commit(
        _withShapes([
          for (final s in _document.shapes)
            if (!_selection.contains(s.id)) s,
        ]),
        select: null,
      );
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
  ///
  /// A multi-selection is copied the same way as one history entry: the
  /// copies keep their stacking order on top and are selected, and the
  /// copies of a group form a new group (spec 05, MS-5). Joints are not
  /// copied, as for a single shape.
  void duplicateSelected() {
    if (_selection.length > 1) {
      _duplicateSelection();
      return;
    }
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
  ///
  /// A multi-selection turns as one history entry around the center of its
  /// bounding box: every shape rotates by [radians] and its center turns
  /// around that point, kept inside the canvas (spec 05, MS-5).
  void rotateSelectedBy(double radians) {
    if (_selection.length > 1) {
      final pivot = boundsOfShapes(_selectedShapes).center;
      _commit(
        _withShapes([
          for (final s in _document.shapes)
            _selection.contains(s.id)
                ? s.copyWith(
                    center: clampToCanvas(
                      pivot + rotateVector(s.center - pivot, radians),
                      _document.canvasSize,
                    ),
                    rotation: s.rotation + radians,
                  )
                : s,
        ]),
      );
      return;
    }
    final selected = _selected;
    if (selected == null) return;
    _replaceSelected(selected.copyWith(rotation: selected.rotation + radians));
  }

  /// Moves the selected shape to the top of the stack. A multi-selection
  /// moves as one history entry and keeps its relative order (spec 05,
  /// MS-5).
  void bringToFront() {
    if (_selection.length > 1) {
      _commit(
        _withShapes([
          for (final s in _document.shapes)
            if (!_selection.contains(s.id)) s,
          ..._selectedShapes,
        ]),
      );
      return;
    }
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

  /// Moves the selected shape to the bottom of the stack. A
  /// multi-selection moves as one history entry and keeps its relative
  /// order (spec 05, MS-5).
  void sendToBack() {
    if (_selection.length > 1) {
      _commit(
        _withShapes([
          ..._selectedShapes,
          for (final s in _document.shapes)
            if (!_selection.contains(s.id)) s,
        ]),
      );
      return;
    }
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
        jointStyle: config.jointStyle,
      );

  ShapeElement? get _selected {
    final id = selectedId;
    if (id == null) return null;
    for (final shape in _document.shapes) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  /// The selected shapes in stacking order.
  List<ShapeElement> get _selectedShapes => [
    for (final shape in _document.shapes)
      if (_selection.contains(shape.id)) shape,
  ];

  /// The group whose members are exactly the selection, or null.
  ShapeGroup? get _selectedGroup {
    for (final group in _document.groups) {
      if (group.shapeIds.length == _selection.length &&
          group.shapeIds.every(_selection.contains)) {
        return group;
      }
    }
    return null;
  }

  /// [ids] plus every other member of their groups.
  Set<String> _withGroupMates(Iterable<String> ids) {
    final result = {...ids};
    for (final group in _document.groups) {
      if (group.shapeIds.any(result.contains)) result.addAll(group.shapeIds);
    }
    return result;
  }

  /// Replaces the selection with [ids] and their groups (MS-6).
  void _setSelection(Iterable<String> ids) {
    final next = _withGroupMates(ids);
    _selection
      ..clear()
      ..addAll(next);
  }

  /// The document with [shapes], keeping the joints whose shape survives
  /// and the groups normalized against them (spec 05, MS-7).
  DrawingDocument _withShapes(
    List<ShapeElement> shapes, {
    List<ShapeGroup>? groups,
  }) {
    final ids = {for (final shape in shapes) shape.id};
    return _normalizeGroups(
      _document.copyWith(
        shapes: shapes,
        joints: [
          for (final joint in _document.joints)
            if (ids.contains(joint.shapeId)) joint,
        ],
        groups: groups,
      ),
    );
  }

  /// Copies the multi-selection on top, with the copies of each group in a
  /// new group, and selects the copies (spec 05, MS-5).
  void _duplicateSelection() {
    final copies = <String, ShapeElement>{};
    for (final shape in _selectedShapes) {
      copies[shape.id] = shape.copyWith(
        id: _uniqueId(copies.values.map((c) => c.id)),
        center: clampToCanvas(
          shape.center + const Offset(cascadeOffset, cascadeOffset),
          _document.canvasSize,
        ),
      );
    }
    final newGroups = <ShapeGroup>[];
    for (final group in _document.groups) {
      if (!group.shapeIds.every(copies.containsKey)) continue;
      newGroups.add(
        ShapeGroup(
          id: _uniqueGroupId(newGroups.map((g) => g.id)),
          shapeIds: [for (final id in group.shapeIds) copies[id]!.id],
        ),
      );
    }
    _commit(
      _withShapes(
        [..._document.shapes, ...copies.values],
        groups: [..._document.groups, ...newGroups],
      ),
      select: [for (final copy in copies.values) copy.id],
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
  ///
  /// [select] is a shape id, a list of shape ids, null to clear, or
  /// [_keepSelection].
  void _applySelection(Object? select, Object? selectJoint) {
    if (select != _keepSelection) {
      _setSelection(switch (select) {
        null => const <String>[],
        final String id => [id],
        final List<String> ids => ids,
        _ => throw ArgumentError.value(select, 'select'),
      });
      if (_selection.isNotEmpty) _selectedJointId = null;
    }
    if (selectJoint != _keepSelection) {
      _selectedJointId = selectJoint as String?;
      if (_selectedJointId != null) _selection.clear();
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

  /// A new shape id, unused by the document and by [reserved].
  String _uniqueId([Iterable<String> reserved = const []]) {
    final taken = {for (final s in _document.shapes) s.id, ...reserved};
    var id = _nextId();
    while (taken.contains(id)) {
      id = _nextId();
    }
    return id;
  }

  /// A new group id, unused by the document and by [reserved].
  String _uniqueGroupId([Iterable<String> reserved = const []]) {
    final taken = {for (final g in _document.groups) g.id, ...reserved};
    var id = _nextGroupId();
    while (taken.contains(id)) {
      id = _nextGroupId();
    }
    return id;
  }

  /// Spec 03, PL-2: the start position (grid-snapped, kept inside the
  /// canvas), or the first diagonal step from it not taken by a shape of
  /// the same type. Steps go
  /// +[cascadeOffset] until the next one would leave the canvas, then
  /// -[cascadeOffset] from the start; when both are exhausted, the start.
  Offset _cascadePosition(ShapeType type, Offset? center) {
    final canvas = _document.canvasSize;
    final grid = config.gridSize;
    var start = center ?? canvas.center(Offset.zero);
    if (grid != null) {
      // Rounding can pass the far edge of a canvas that is not a multiple
      // of the grid; step back to the last grid line inside.
      double inside(double v, double extent) =>
          v > extent ? (extent / grid).floor() * grid : v;
      final snapped = snapPointToGrid(start, grid);
      start = Offset(
        inside(snapped.dx, canvas.width),
        inside(snapped.dy, canvas.height),
      );
    }
    bool taken(Offset position) =>
        _document.shapes.any((s) => s.type == type && s.center == position);
    bool inside(Offset p) =>
        p.dx >= 0 && p.dy >= 0 && p.dx <= canvas.width && p.dy <= canvas.height;
    for (final step in const [
      Offset(cascadeOffset, cascadeOffset),
      Offset(-cascadeOffset, -cascadeOffset),
    ]) {
      var position = start;
      while (inside(position)) {
        if (!taken(position)) return position;
        position += step;
      }
    }
    return start;
  }

  /// Lets the same-library gesture extension notify listeners, since
  /// [notifyListeners] is protected.
  void _notify() => notifyListeners();

  /// Drops selected ids that no longer exist and completes the groups of
  /// the rest (MS-6), and drops a stale or hidden joint selection.
  void _dropStaleSelection() {
    final shapeIds = {for (final s in _document.shapes) s.id};
    _setSelection(_selection.where(shapeIds.contains).toList());
    if (selectedJoint == null || !_document.jointsVisible) {
      _selectedJointId = null;
    }
  }

  void _cancelGestureSilently() {
    _snapHighlight = const [];
    _snapTarget = null;
    if (_gestureStart != null) {
      _document = _gestureStart!;
      _gestureStart = null;
    }
  }
}

const Object _keepSelection = Object();

/// [document] with its groups normalized against its shapes (spec 05,
/// MS-7): members that are not shapes of the document and members already
/// in an earlier group are dropped, and so is a group left with fewer than
/// two shapes. Returns [document] itself when nothing changes, so the
/// encoder never writes groups that `DrawingDocument.fromJson` rejects
/// (PS-6).
DrawingDocument _normalizeGroups(DrawingDocument document) {
  final shapeIds = {for (final s in document.shapes) s.id};
  final grouped = <String>{};
  final groups = <ShapeGroup>[];
  final groupIds = <String>{};
  var changed = false;
  for (final group in document.groups) {
    final members = [
      for (final id in group.shapeIds)
        if (shapeIds.contains(id) && grouped.add(id)) id,
    ];
    if (members.length < 2 || !groupIds.add(group.id)) {
      grouped.removeAll(members);
      changed = true;
      continue;
    }
    if (members.length != group.shapeIds.length) {
      changed = true;
      groups.add(ShapeGroup(id: group.id, shapeIds: members));
    } else {
      groups.add(group);
    }
  }
  return changed ? document.copyWith(groups: groups) : document;
}

/// Gesture and selection operations used by the editor widgets.
///
/// Not exported from the public library.
extension DrawingEditorGestures on DrawingEditorController {
  /// The selected shape, or null.
  ShapeElement? get selectedShape => _selected;

  /// The selected shapes, in stacking order: empty, one or many.
  List<ShapeElement> get selectedShapes => _selectedShapes;

  /// The group whose members are exactly the selected shapes, or null
  /// (spec 05, MS-6).
  ShapeGroup? get selectedGroup => _selectedGroup;

  /// Selects the shape with [id] and the rest of its group (spec 05, MS-6),
  /// or clears the selection with null. Clears any joint selection.
  void select(String? id) {
    final next = id == null ? const <String>{} : _withGroupMates([id]);
    if (setEquals(next, _selection) && _selectedJointId == null) return;
    _setSelection(next);
    _selectedJointId = null;
    _notify();
  }

  /// Selects the joint with [id], or clears the selection with null.
  /// Clears any shape selection.
  ///
  /// While joints are hidden, no joint can be selected: [id] counts as null
  /// (spec 04, JV-2).
  void selectJoint(String? id) {
    if (!_document.jointsVisible) id = null;
    if (_selectedJointId == id && _selection.isEmpty) return;
    _selectedJointId = id;
    _selection.clear();
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
    _document = _document.copyWith(
      joints: [..._document.joints, joint],
      jointsVisible: true,
    );
    _selectedJointId = joint.id;
    _selection.clear();
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

  /// The two anchor positions of the active anchor snap, for the highlight
  /// (spec 02, SN-3); empty when no snap is active.
  List<Offset> get snapHighlight => _snapHighlight;

  /// Identity of the engaged snap during a gesture, or null: the snapped
  /// angle for rotation, or the (target shape id, target anchor id) pair
  /// for anchor snapping. Grid snapping is never a target. The editor
  /// plays a haptic when it changes (spec 03, HP-1 to HP-3).
  Object? get snapTarget => _snapTarget;

  /// Moves the selected shape by [delta] from its position at gesture start,
  /// snapping the center to the grid (FR-9) and clamping it to the canvas
  /// (FR-10).
  ///
  /// With [anchorSnapDistance] (canvas units), an anchor of the shape that
  /// comes that close to another shape's anchor snaps onto it instead of
  /// the grid; only the nearest pair applies (spec 02, SN-1, SN-3).
  ///
  /// With [gridStep], the visible grid step captured when the gesture
  /// started, grid snapping uses it instead of
  /// [DrawingEditorConfig.gridSize]: at a multiple of 90° the nearest
  /// bounding box edges land on grid lines, otherwise the center snaps to
  /// the step (spec 05, GA-1, GA-3, GA-5). Anchor snapping keeps priority
  /// (GA-7). Without it, snapping is unchanged (GA-2).
  ///
  /// A multi-selection moves as one shape (spec 05, MS-4): any selected
  /// anchor snaps onto an unselected shape's anchor first; otherwise the
  /// selection's bounding box snaps at [gridStep] (or
  /// [DrawingEditorConfig.gridSize] while the grid is hidden), by its edges
  /// when every selected shape is at a multiple of 90° and by its center
  /// otherwise. The selection stays rigid while its centers are kept inside
  /// the canvas.
  void moveSelectedBy(
    Offset delta, {
    double? anchorSnapDistance,
    double? gridStep,
  }) {
    if (_selection.length > 1) {
      _moveSelectionBy(
        delta,
        anchorSnapDistance: anchorSnapDistance,
        gridStep: gridStep,
      );
      return;
    }
    final start = _gestureShape;
    if (start == null) return;
    _snapHighlight = const [];
    _snapTarget = null;
    final raw = start.center + delta;
    var center = raw;
    final others = _otherAnchors({start.id});
    final snap = anchorSnapDistance == null
        ? null
        : nearestAnchorSnap(anchors.anchorsOf(start.copyWith(center: raw)), [
            for (final other in others) other.anchor,
          ], threshold: anchorSnapDistance);
    _snapTarget = snap == null ? null : others[snap.targetIndex].key;
    final grid = config.gridSize;
    if (snap != null) {
      center = raw + snap.delta;
      _snapHighlight = [snap.to, snap.to];
    } else if (gridStep != null) {
      center = snapMoveToGrid(
        center,
        size: start.size,
        rotation: start.rotation,
        step: gridStep,
      );
    } else if (grid != null) {
      center = snapPointToGrid(center, grid);
    }
    center = clampToCanvas(center, _document.canvasSize);
    _preview(start.copyWith(center: center));
  }

  /// Resizes the selected shape by dragging [handle] to [pointer]
  /// (FR-11 to FR-14).
  ///
  /// With [anchorSnapDistance] (canvas units), only the anchor under
  /// [handle] may snap onto another shape's anchor, taking priority over
  /// the grid (spec 02, SN-2, SN-3).
  ///
  /// With [gridStep], the visible grid step captured when the gesture
  /// started, the dragged edges snap to grid lines at that step instead of
  /// sizes to multiples of `2 × gridSize`, and the minimum size is at
  /// least one step (spec 05, GA-1, GA-4 to GA-6). Without it, resizing is
  /// unchanged (GA-2).
  void resizeSelected(
    ResizeHandle handle,
    Offset pointer, {
    double? anchorSnapDistance,
    double? gridStep,
  }) {
    final start = _gestureShape;
    if (start == null) return;
    _snapHighlight = const [];
    _snapTarget = null;
    final grid = config.gridSize;
    final limits = SizeLimits.forCanvas(
      _document.canvasSize,
      gridSize: grid,
      gridStep: gridStep,
    );
    if (anchorSnapDistance != null) {
      final snapped = _snappedResize(
        start,
        handle,
        pointer,
        limits,
        anchorSnapDistance,
      );
      if (snapped != null) {
        _preview(snapped);
        return;
      }
    }
    _preview(
      resizeShape(
        start,
        handle,
        pointer,
        limits: limits,
        gridSize: grid,
        gridStep: gridStep,
      ),
    );
  }

  /// The resize that puts [handle]'s anchor exactly on a nearby anchor of
  /// another shape, or null when there is none or it cannot land exactly
  /// (for example under an aspect lock or a size limit).
  ShapeElement? _snappedResize(
    ShapeElement start,
    ResizeHandle handle,
    Offset pointer,
    SizeLimits limits,
    double distance,
  ) {
    final anchorId = anchorIdForHandle(handle);
    final others = _otherAnchors({start.id});
    final free = resizeShape(start, handle, pointer, limits: limits);
    final position = anchorPositionOf(free, anchorId);
    if (position == null) return null;
    final snap = nearestAnchorSnap(
      [Anchor(id: anchorId, kind: AnchorKind.vertex, position: position)],
      [for (final other in others) other.anchor],
      threshold: distance,
    );
    if (snap == null) return null;
    final snapped = resizeShape(start, handle, snap.to, limits: limits);
    final landed = anchorPositionOf(snapped, anchorId);
    if (landed == null || (landed - snap.to).distance > 1e-6) return null;
    _snapHighlight = [snap.to, landed];
    _snapTarget = others[snap.targetIndex].key;
    return snapped;
  }

  /// Anchors of every shape not in [shapeIds], in the current document,
  /// each with its (shape id, anchor id) key.
  List<({Anchor anchor, (String, String) key})> _otherAnchors(
    Set<String> shapeIds,
  ) => [
    for (final shape in _document.shapes)
      if (!shapeIds.contains(shape.id))
        for (final anchor in anchors.anchorsOf(shape))
          (anchor: anchor, key: (shape.id, anchor.id)),
  ];

  /// The multi-selection part of [moveSelectedBy] (spec 05, MS-4).
  void _moveSelectionBy(
    Offset delta, {
    double? anchorSnapDistance,
    double? gridStep,
  }) {
    final start = _gestureStart;
    if (start == null) return;
    final moving = [
      for (final shape in start.shapes)
        if (_selection.contains(shape.id)) shape,
    ];
    if (moving.isEmpty) return;
    _snapHighlight = const [];
    _snapTarget = null;
    final others = _otherAnchors(_selection);
    final snap = anchorSnapDistance == null
        ? null
        : nearestAnchorSnap(
            [
              for (final shape in moving)
                ...anchors.anchorsOf(
                  shape.copyWith(center: shape.center + delta),
                ),
            ],
            [for (final other in others) other.anchor],
            threshold: anchorSnapDistance,
          );
    final step = gridStep ?? config.gridSize;
    var shift = delta;
    if (snap != null) {
      shift = delta + snap.delta;
      _snapHighlight = [snap.to, snap.to];
      _snapTarget = others[snap.targetIndex].key;
    } else if (step != null) {
      shift = snapBoxShiftToGrid(
        boundsOfShapes(moving),
        delta,
        step: step,
        edges: moving.every((s) => isQuarterTurn(s.rotation)),
      );
    }
    shift = _clampShift(moving, shift);
    final byId = {for (final shape in moving) shape.id: shape};
    _document = _withShapes([
      for (final s in _document.shapes)
        if (byId[s.id] case final from?)
          from.copyWith(center: from.center + shift)
        else
          s,
    ]);
    _notify();
  }

  /// [shift] limited so every center of [shapes] stays inside the canvas
  /// (FR-10) while the shapes keep their relative positions.
  Offset _clampShift(List<ShapeElement> shapes, Offset shift) {
    final canvas = _document.canvasSize;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final shape in shapes) {
      minX = math.min(minX, shape.center.dx);
      maxX = math.max(maxX, shape.center.dx);
      minY = math.min(minY, shape.center.dy);
      maxY = math.max(maxY, shape.center.dy);
    }
    double clampAxis(double v, double low, double high) =>
        low > high ? v : v.clamp(low, high);
    return Offset(
      clampAxis(shift.dx, -minX, canvas.width - maxX),
      clampAxis(shift.dy, -minY, canvas.height - maxY),
    );
  }

  /// Rotates the selected shape so its rotation handle points at [pointer],
  /// with soft snapping (FR-15, FR-16).
  void rotateSelectedToward(Offset pointer) {
    final start = _gestureShape;
    if (start == null) return;
    _snapHighlight = const [];
    _snapTarget = null;
    final raw = normalizeAngle(rotationFromPointer(start.center, pointer));
    final snap = softSnap(
      raw,
      config.rotationSnapStep,
      config.rotationSnapTolerance,
    );
    // The snapped angle identifies the engaged snap (spec 03, HP-2).
    _snapTarget = snap.snapped ? snap.angle : null;
    _preview(start.copyWith(rotation: snap.angle));
  }

  /// Ends the gesture, recording one history entry if anything changed.
  void endGesture() {
    final start = _gestureStart;
    if (start == null) return;
    _gestureStart = null;
    _snapTarget = null;
    if (_snapHighlight.isNotEmpty) {
      _snapHighlight = const [];
      _notify();
    }
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
    final id = selectedId;
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
