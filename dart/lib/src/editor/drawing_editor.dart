import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';

import '../geometry/hit_testing.dart';
import '../geometry/joint_geometry.dart';
import '../geometry/resize.dart';
import '../geometry/transforms.dart';
import '../geometry/viewport.dart';
import '../model/shape_element.dart';
import '../model/shape_type.dart';
import '../painting/editor_painters.dart';
import '../painting/joint_painting.dart';
import 'drawing_editor_controller.dart';
import 'drawing_editor_labels.dart';
import 'drawing_tool.dart';

enum _GestureMode { none, move, resize, rotate, pinch, labelDrag }

/// Anchor touch radius in the Joint tool, in dp (spec 02, JT-2).
const double _anchorTouchRadius = 22;

/// Anchors whose distances differ by less than this, in dp, go to the
/// topmost shape (spec 02, JT-4).
const double _anchorTieTolerance = 2;

/// Extra touch margin around a joint label, in dp.
const double _labelTouchMargin = 4;

/// Touch distance from a leader arrow, in dp.
const double _arrowTouchDistance = 12;

/// Embeddable drawing editor: canvas, shape palette and selection toolbar.
///
/// The [controller] owns the document; this widget only renders it and
/// turns touches into edits.
class DrawingEditor extends StatefulWidget {
  /// Creates an editor for [controller].
  const DrawingEditor({
    super.key,
    required this.controller,
    this.labels = const DrawingEditorLabels(),
  });

  /// Key of the canvas area, for tests that convert canvas coordinates.
  @visibleForTesting
  static const Key canvasKey = ValueKey('soft_drawer_service.canvas');

  /// Controller holding the document and history.
  final DrawingEditorController controller;

  /// User-visible strings.
  final DrawingEditorLabels labels;

  @override
  State<DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<DrawingEditor> {
  CanvasViewport _viewport = const CanvasViewport(
    scale: 1,
    origin: Offset.zero,
  );
  _GestureMode _mode = _GestureMode.none;
  ResizeHandle? _handle;
  Offset _startFocal = Offset.zero;

  /// Pinch zoom and pan over the fitted viewport (FR-2).
  ViewportZoom _zoom = const ViewportZoom();
  ViewportZoom _pinchStartZoom = const ViewportZoom();
  Size _areaSize = Size.zero;

  /// Pointers currently down on the canvas.
  int _activePointers = 0;

  /// Set once two fingers touch; one-finger gestures stay disabled until
  /// every finger lifts, so the finger left after a pinch edits nothing.
  bool _multiTouch = false;

  /// Joint whose label was just tapped; a second tap on it before
  /// [_doubleTapTimer] fires opens the rename editor (spec 02, NM-2).
  /// Single taps are not delayed.
  String? _tappedJointId;
  Timer? _doubleTapTimer;

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  /// Where the most recent pointer went down. The scale recognizer reports
  /// its start only after the touch slop, so gestures start from here.
  Offset? _pointerDown;

  DrawingEditorController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        children: [
          Expanded(child: _buildCanvas(context)),
          _buildToolbar(context),
        ],
      ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final theme = Theme.of(context);
    final config = _controller.config;
    final document = _controller.document;
    return LayoutBuilder(
      builder: (context, constraints) {
        _areaSize = constraints.biggest;
        _zoom = _zoom.clamped(document.canvasSize, _areaSize);
        _viewport = _zoom.apply(
          CanvasViewport.fit(document.canvasSize, _areaSize),
        );
        return ClipRect(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: (_) => _onPointerGone(),
            onPointerCancel: (_) => _onPointerGone(),
            child: GestureDetector(
              key: DrawingEditor.canvasKey,
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _onTap(details.localPosition),
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: (_) => _onScaleEnd(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: BackgroundPainter(
                        viewport: _viewport,
                        canvasSize: document.canvasSize,
                        gridSize: _controller.gridVisible
                            ? config.gridSize
                            : null,
                        gridMajorEvery: config.gridMajorEvery,
                        gridColor: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: ShapesPainter(
                        document: document,
                        viewport: _viewport,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: JointsPainter(
                        document: document,
                        viewport: _viewport,
                        style: config.jointStyle,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: SelectionPainter(
                            shape: _controller.selectedShape,
                            viewport: _viewport,
                            color: theme.colorScheme.primary,
                            showAngle: _mode == _GestureMode.rotate,
                          ),
                        ),
                        CustomPaint(
                          painter: JointOverlayPainter(
                            document: document,
                            viewport: _viewport,
                            style: config.jointStyle,
                            color:
                                config.jointStyle.selectionColor ??
                                theme.colorScheme.primary,
                            showAnchors: _controller.tool == DrawingTool.joint,
                            selectedJoint: _controller.selectedJoint,
                            snapPoints: _controller.snapHighlight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final labels = widget.labels;
    final hasSelection = _controller.selectedShape != null;
    final selectedJoint = _controller.selectedJoint;
    final jointTool = _controller.tool == DrawingTool.joint;
    Widget action(IconData icon, String label, VoidCallback? onPressed) =>
        IconButton(icon: Icon(icon), tooltip: label, onPressed: onPressed);
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            action(
              Icons.crop_square,
              labels.addSquare,
              () => _controller.addShape(ShapeType.square),
            ),
            action(
              Icons.rectangle_outlined,
              labels.addRectangle,
              () => _controller.addShape(ShapeType.rectangle),
            ),
            action(
              Icons.circle_outlined,
              labels.addCircle,
              () => _controller.addShape(ShapeType.circle),
            ),
            IconButton(
              icon: const Icon(Icons.adjust),
              tooltip: labels.jointTool,
              isSelected: jointTool,
              onPressed: () => _controller.tool = jointTool
                  ? DrawingTool.select
                  : DrawingTool.joint,
            ),
            if (selectedJoint != null) ...[
              action(
                Icons.edit_outlined,
                labels.renameJoint,
                () => _renameJoint(selectedJoint.id),
              ),
              action(
                Icons.delete_outline,
                labels.deleteJoint,
                () => _controller.removeJoint(selectedJoint.id),
              ),
            ],
            if (hasSelection) ...[
              action(
                Icons.rotate_right,
                labels.rotate90,
                () => _controller.rotateSelectedBy(math.pi / 2),
              ),
              action(
                Icons.copy_outlined,
                labels.duplicate,
                _controller.duplicateSelected,
              ),
              action(
                Icons.flip_to_front,
                labels.bringToFront,
                _controller.bringToFront,
              ),
              action(
                Icons.flip_to_back,
                labels.sendToBack,
                _controller.sendToBack,
              ),
              action(
                Icons.delete_outline,
                labels.delete,
                _controller.deleteSelected,
              ),
            ],
            action(
              Icons.undo,
              labels.undo,
              _controller.canUndo ? _controller.undo : null,
            ),
            action(
              Icons.redo,
              labels.redo,
              _controller.canRedo ? _controller.redo : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Handle under [canvasPoint] on the selected shape, or null.
  ({_GestureMode mode, ResizeHandle? handle})? _handleAt(Offset canvasPoint) {
    final shape = _controller.selectedShape;
    if (shape == null || _controller.tool == DrawingTool.joint) return null;
    final radius = _viewport.canvasLength(handleTouchRadius);
    if ((rotationHandlePosition(shape, _viewport) - canvasPoint).distance <=
        radius) {
      return (mode: _GestureMode.rotate, handle: null);
    }
    ResizeHandle? nearest;
    var nearestDistance = double.infinity;
    for (final handle in handlesFor(shape.type)) {
      final distance = (_handleWorld(shape, handle) - canvasPoint).distance;
      if (distance <= radius && distance < nearestDistance) {
        nearest = handle;
        nearestDistance = distance;
      }
    }
    return nearest == null
        ? null
        : (mode: _GestureMode.resize, handle: nearest);
  }

  Offset _handleWorld(ShapeElement shape, ResizeHandle handle) =>
      worldFromLocal(
        shape.center,
        shape.rotation,
        handle.localPosition(shape.size),
      );

  /// Id of the joint whose label or leader arrow is under [canvasPoint],
  /// topmost first, or null.
  String? _jointAt(Offset canvasPoint) {
    final placements = placeJoints(
      _controller.document,
      _controller.config.jointStyle,
    );
    String? hit;
    for (final placement in placements.reversed) {
      final label = placement.labelRect.inflate(
        _viewport.canvasLength(_labelTouchMargin),
      );
      final start = leaderLineStart(placement.labelRect, placement.anchor);
      final onArrow =
          start != null &&
          distanceToSegment(canvasPoint, start, placement.anchor) <=
              _viewport.canvasLength(_arrowTouchDistance);
      if (label.contains(canvasPoint) || onArrow) {
        hit = placement.joint.id;
        break;
      }
    }
    for (final placement in placements) {
      placement.dispose();
    }
    return hit;
  }

  void _onTap(Offset localPosition) {
    final point = _viewport.toCanvas(localPosition);
    if (_handleAt(point) != null) return;

    final jointId = _jointAt(point);
    if (jointId != null) {
      _onJointTap(jointId);
      return;
    }

    final document = _controller.document;
    if (_controller.tool == DrawingTool.joint) {
      final hit = pickAnchor(
        document.shapes,
        point,
        radius: _viewport.canvasLength(_anchorTouchRadius),
        tieTolerance: _viewport.canvasLength(_anchorTieTolerance),
      );
      if (hit == null) {
        _controller.select(null);
        return;
      }
      final existing = document.joints
          .where((j) => j.shapeId == hit.shapeId && j.anchorId == hit.anchorId)
          .firstOrNull;
      if (existing != null) {
        _controller.selectJoint(existing.id);
      } else {
        _createJoint(hit.shapeId, hit.anchorId);
      }
      return;
    }
    _controller.select(topmostShapeAt(document.shapes, point)?.id);
  }

  void _onJointTap(String jointId) {
    _doubleTapTimer?.cancel();
    if (_tappedJointId == jointId) {
      _tappedJointId = null;
      _controller.selectJoint(jointId);
      _renameJoint(jointId);
      return;
    }
    _tappedJointId = jointId;
    _doubleTapTimer = Timer(kDoubleTapTimeout, () => _tappedJointId = null);
    _controller.selectJoint(jointId);
  }

  Future<void> _createJoint(String shapeId, String anchorId) async {
    final joint = _controller.beginJointCreation(shapeId, anchorId);
    final name = await _editJointName(joint.name);
    if (!mounted) return;
    _controller.confirmJointCreation(name ?? '');
  }

  Future<void> _renameJoint(String jointId) async {
    final joint = _controller.document.joints
        .where((j) => j.id == jointId)
        .firstOrNull;
    if (joint == null) return;
    final name = await _editJointName(joint.name);
    if (!mounted || name == null) return;
    if (_controller.document.joints.any((j) => j.id == jointId)) {
      _controller.renameJoint(jointId, name);
    }
  }

  /// Shows the name editor; returns the entered text, or null when it is
  /// cancelled or dismissed.
  Future<String?> _editJointName(String initial) => showDialog<String>(
    context: context,
    builder: (context) => _JointNameDialog(
      initial: initial,
      maxLength: _controller.config.jointNameMaxLength,
      labels: widget.labels,
    ),
  );

  /// The anchor snap threshold in canvas units at the current zoom, or null
  /// when anchor snapping is disabled.
  double? get _anchorSnapDistance {
    final threshold = _controller.config.anchorSnapThreshold;
    return threshold == null ? null : _viewport.canvasLength(threshold);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.localPosition;
    _activePointers++;
    if (_activePointers > 1) _multiTouch = true;
  }

  void _onPointerGone() {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) _multiTouch = false;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      _multiTouch = true;
      _startFocal = details.localFocalPoint;
      _pinchStartZoom = _zoom;
      _mode = _GestureMode.pinch;
      return;
    }
    if (_multiTouch) return;
    _startFocal = _pointerDown ?? details.localFocalPoint;
    final point = _viewport.toCanvas(_startFocal);
    final handleHit = _handleAt(point);
    final jointId = handleHit == null ? _jointAt(point) : null;
    if (handleHit != null) {
      _mode = handleHit.mode;
      _handle = handleHit.handle;
    } else if (jointId != null) {
      _controller.selectJoint(jointId);
      _mode = _GestureMode.labelDrag;
    } else if (_controller.tool == DrawingTool.joint) {
      return;
    } else {
      final shape = topmostShapeAt(_controller.document.shapes, point);
      if (shape == null) return;
      _controller.select(shape.id);
      _mode = _GestureMode.move;
    }
    _controller.beginGesture();
    setState(() {});
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    switch (_mode) {
      case _GestureMode.none:
        return;
      case _GestureMode.pinch:
        setState(() {
          _zoom = _pinchStartZoom
              .pinch(
                startFocal: _startFocal,
                focal: details.localFocalPoint,
                scale: details.scale,
              )
              .clamped(_controller.document.canvasSize, _areaSize);
        });
      case _GestureMode.labelDrag:
        _controller.dragSelectedJointLabelBy(
          (details.localFocalPoint - _startFocal) / _viewport.scale,
        );
      case _GestureMode.move:
        _controller.moveSelectedBy(
          (details.localFocalPoint - _startFocal) / _viewport.scale,
          anchorSnapDistance: _anchorSnapDistance,
        );
      case _GestureMode.resize:
        _controller.resizeSelected(
          _handle!,
          _viewport.toCanvas(details.localFocalPoint),
          anchorSnapDistance: _anchorSnapDistance,
        );
      case _GestureMode.rotate:
        _controller.rotateSelectedToward(
          _viewport.toCanvas(details.localFocalPoint),
        );
    }
  }

  void _onScaleEnd() {
    if (_mode == _GestureMode.none) return;
    if (_mode == _GestureMode.pinch) {
      _mode = _GestureMode.none;
      return;
    }
    _controller.endGesture();
    setState(() {
      _mode = _GestureMode.none;
      _handle = null;
    });
  }
}

/// Single-line joint name editor (spec 02, NM-1).
class _JointNameDialog extends StatefulWidget {
  const _JointNameDialog({
    required this.initial,
    required this.maxLength,
    required this.labels,
  });

  final String initial;
  final int maxLength;
  final DrawingEditorLabels labels;

  @override
  State<_JointNameDialog> createState() => _JointNameDialogState();
}

class _JointNameDialogState extends State<_JointNameDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    return AlertDialog(
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          hintText: labels.jointNameHint,
          counterText: '',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(labels.ok),
        ),
      ],
    );
  }
}
