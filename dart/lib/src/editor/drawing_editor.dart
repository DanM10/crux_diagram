import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kDoubleTapSlop, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../geometry/hit_testing.dart';
import '../geometry/joint_geometry.dart';
import '../geometry/resize.dart';
import '../geometry/transforms.dart';
import '../geometry/viewport.dart';
import '../model/drawing_document.dart';
import '../model/shape_element.dart';
import '../painting/editor_painters.dart';
import '../painting/joint_painting.dart';
import 'drawing_editor_controller.dart';
import 'drawing_editor_labels.dart';
import 'drawing_editor_config.dart';
import 'drawing_tool.dart';
import 'editor_toolbar.dart';
import 'snap_haptics.dart';

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

/// Zoom above which the view counts as zoomed in (spec 03, ZM-1).
const double _zoomedInThreshold = 1.005;

/// Zoom that a double-tap on empty canvas zooms to (spec 03, ZM-3).
const double _doubleTapZoom = 2;

/// Duration of fit-to-screen and double-tap zoom changes (spec 03, ZM-7).
const Duration _zoomAnimationDuration = Duration(milliseconds: 200);

class _DrawingEditorState extends State<DrawingEditor>
    with SingleTickerProviderStateMixin {
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

  /// Where the last tap on empty canvas landed; a second one within
  /// [kDoubleTapTimeout] and [kDoubleTapSlop] toggles zoom (spec 03, ZM-4).
  /// Single taps are not delayed.
  Offset? _emptyTapPosition;
  Timer? _emptyTapTimer;

  /// Animates zoom changes from fit to screen and double-tap (ZM-7).
  late final AnimationController _zoomAnimation;

  /// Decides when a snap haptic plays (spec 03, HP-1, HP-2).
  final SnapHapticTracker _snapHaptics = SnapHapticTracker();

  ViewportZoom _zoomFrom = const ViewportZoom();
  ViewportZoom _zoomTo = const ViewportZoom();

  @override
  void initState() {
    super.initState();
    _zoomAnimation = AnimationController(
      vsync: this,
      duration: _zoomAnimationDuration,
    )..addListener(_onZoomAnimationTick);
  }

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    _emptyTapTimer?.cancel();
    _zoomAnimation.dispose();
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
          EditorToolbar(
            controller: _controller,
            labels: widget.labels,
            onAddShape: (type) => _controller.addShape(
              type,
              center: _viewport.visibleCenter(
                _areaSize,
                _controller.document.canvasSize,
              ),
            ),
            onRenameJoint: _renameJoint,
          ),
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
        // Overlays are Stack siblings above the canvas Listener, so taps on
        // them never reach the canvas (spec 03, JM-3, ZM-6).
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildCanvasLayers(theme, config, document),
            if (_controller.tool == DrawingTool.joint)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _JointHintBar(
                  labels: widget.labels,
                  onExit: () => _controller.tool = DrawingTool.select,
                ),
              ),
            if (_zoom.zoom > _zoomedInThreshold)
              PositionedDirectional(
                end: 16,
                bottom: 16,
                child: _ZoomControls(
                  labels: widget.labels,
                  percent: (_zoom.zoom * 100).round(),
                  onFit: () => _animateZoomTo(const ViewportZoom()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCanvasLayers(
    ThemeData theme,
    DrawingEditorConfig config,
    DrawingDocument document,
  ) {
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
                    gridSize: _controller.gridVisible ? config.gridSize : null,
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
      _emptyTapPosition = null;
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
    final shape = topmostShapeAt(document.shapes, point);
    _controller.select(shape?.id);
    if (shape == null) {
      _onEmptyCanvasTap(localPosition);
    } else {
      _emptyTapPosition = null;
    }
  }

  /// Spec 03, ZM-3, ZM-4: the first tap has already acted; a second tap on
  /// empty canvas close in time and space toggles zoom.
  void _onEmptyCanvasTap(Offset localPosition) {
    _emptyTapTimer?.cancel();
    final previous = _emptyTapPosition;
    if (previous != null &&
        (localPosition - previous).distance <= kDoubleTapSlop) {
      _emptyTapPosition = null;
      _animateZoomTo(
        _zoom.zoom > _zoomedInThreshold
            ? const ViewportZoom()
            : _zoom.pinch(
                startFocal: localPosition,
                focal: localPosition,
                scale: _doubleTapZoom / _zoom.zoom,
              ),
      );
      return;
    }
    _emptyTapPosition = localPosition;
    _emptyTapTimer = Timer(kDoubleTapTimeout, () => _emptyTapPosition = null);
  }

  /// Moves the view to [target] (clamped) over [_zoomAnimationDuration],
  /// or at once when the platform asks for reduced motion (ZM-7). View
  /// changes never touch the document or history (ZM-5).
  void _animateZoomTo(ViewportZoom target) {
    final canvasSize = _controller.document.canvasSize;
    _zoomTo = target.clamped(canvasSize, _areaSize);
    _zoomAnimation.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _zoom = _zoomTo);
      return;
    }
    _zoomFrom = _zoom;
    _zoomAnimation.forward(from: 0);
  }

  void _onZoomAnimationTick() {
    final t = Curves.easeOut.transform(_zoomAnimation.value);
    setState(() {
      _zoom = ViewportZoom(
        zoom: _zoomFrom.zoom + (_zoomTo.zoom - _zoomFrom.zoom) * t,
        pan: Offset.lerp(_zoomFrom.pan, _zoomTo.pan, t)!,
      );
    });
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
    // A finger on the canvas stops a running zoom animation where it is.
    _zoomAnimation.stop();
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
    _snapHaptics.reset();
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
        _playSnapHaptic();
      case _GestureMode.resize:
        _controller.resizeSelected(
          _handle!,
          _viewport.toCanvas(details.localFocalPoint),
          anchorSnapDistance: _anchorSnapDistance,
        );
        _playSnapHaptic();
      case _GestureMode.rotate:
        _controller.rotateSelectedToward(
          _viewport.toCanvas(details.localFocalPoint),
        );
        _playSnapHaptic();
    }
  }

  /// Plays a selection click when a rotation or anchor snap engages on a
  /// new target; grid snapping is never a target (spec 03, HP-1 to HP-4).
  void _playSnapHaptic() {
    final play = _snapHaptics.update(_controller.snapTarget);
    if (play && _controller.config.hapticFeedback) {
      HapticFeedback.selectionClick();
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

/// Explains the Joint tool while it is active and offers a way out
/// (spec 03, JM-1, JM-2).
class _JointHintBar extends StatelessWidget {
  const _JointHintBar({required this.labels, required this.onExit});

  final DrawingEditorLabels labels;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  labels.jointModeHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
              TextButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.close),
                label: Text(labels.exitJointMode),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fit-to-screen button and zoom readout, shown while zoomed in
/// (spec 03, ZM-1, ZM-2).
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.labels,
    required this.percent,
    required this.onFit,
  });

  final DrawingEditorLabels labels;
  final int percent;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              labels.zoomPercent(percent),
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: onFit,
          icon: const Icon(Icons.fit_screen),
          label: Text(labels.fitToScreen),
        ),
      ],
    );
  }
}
