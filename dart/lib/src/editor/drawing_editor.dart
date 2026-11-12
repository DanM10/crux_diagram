import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometry/hit_testing.dart';
import '../geometry/resize.dart';
import '../geometry/transforms.dart';
import '../geometry/viewport.dart';
import '../model/shape_element.dart';
import '../model/shape_type.dart';
import '../painting/editor_painters.dart';
import 'drawing_editor_controller.dart';
import 'drawing_editor_labels.dart';

enum _GestureMode { none, move, resize, rotate, pinch }

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
                        gridSize: config.showGrid ? config.gridSize : null,
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
                      painter: SelectionPainter(
                        shape: _controller.selectedShape,
                        viewport: _viewport,
                        color: theme.colorScheme.primary,
                        showAngle: _mode == _GestureMode.rotate,
                      ),
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
    if (shape == null) return null;
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

  void _onTap(Offset localPosition) {
    final point = _viewport.toCanvas(localPosition);
    if (_handleAt(point) != null) return;
    _controller.select(topmostShapeAt(_controller.document.shapes, point)?.id);
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
    if (handleHit != null) {
      _mode = handleHit.mode;
      _handle = handleHit.handle;
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
      case _GestureMode.move:
        _controller.moveSelectedBy(
          (details.localFocalPoint - _startFocal) / _viewport.scale,
        );
      case _GestureMode.resize:
        _controller.resizeSelected(
          _handle!,
          _viewport.toCanvas(details.localFocalPoint),
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
