import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/joint_label_size.dart';
import '../model/shape_type.dart';
import 'drawing_editor_controller.dart';
import 'drawing_editor_labels.dart';
import 'drawing_tool.dart';

/// Smallest width and height of a toolbar button, in dp (spec 03, TB-4,
/// LB-4).
const double _minButtonExtent = 48;

/// Horizontal room around a button label, in dp.
const double _labelPadding = 8;

/// Size of toolbar icons, in dp.
const double _iconSize = 24;

/// Vertical padding around a toolbar icon, in dp.
const double _iconVerticalPadding = 4;

/// Gap between a toolbar icon and its label, in dp.
const double _labelGap = 2;

/// Extra vertical room in a toolbar row beyond the button content, in dp,
/// so the ink splash does not touch the row edges.
const double _rowVerticalSlack = 8;

/// The editor toolbar: the selection bar above the create bar
/// (spec 03, section 4.1).
///
/// With the Joint tool active, the selection bar shows the joint display
/// bar: the three label sizes and the show/hide button (spec 04, JD-1).
///
/// In the select tool the selection bar starts with the Select toggle when
/// nothing is selected or selection mode is on (spec 05, MS-1). A
/// multi-selection shows Group, or Ungroup when it is exactly one group,
/// before the shape actions (MS-5, MS-6).
///
/// The create bar never changes for a given configuration. The selection
/// bar keeps its height when it is empty, so selecting never moves a
/// button or resizes the canvas.
class EditorToolbar extends StatefulWidget {
  /// Creates the toolbar for [controller].
  const EditorToolbar({
    super.key,
    required this.controller,
    required this.labels,
    required this.onAddShape,
    required this.onRenameJoint,
  });

  /// Key of the selection bar, for tests.
  static const Key selectionBarKey = ValueKey('crux_diagram.selectionBar');

  /// Key of the create bar, for tests.
  static const Key createBarKey = ValueKey('crux_diagram.createBar');

  /// Controller holding the document, selection and view state.
  final DrawingEditorController controller;

  /// User-visible strings.
  final DrawingEditorLabels labels;

  /// Adds a shape of the given type where the editor wants it.
  final ValueChanged<ShapeType> onAddShape;

  /// Opens the rename editor for the joint with the given id.
  final ValueChanged<String> onRenameJoint;

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  // Label measurements only change with the style, text scale and
  // direction, not with the controller notifications that rebuild the
  // toolbar on every gesture frame; they are cached per that key.
  (TextStyle?, TextScaler, TextDirection)? _metricsKey;
  final Map<String, double> _labelWidths = {};
  double? _labelHeight;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    super.dispose();
  }

  /// Newly available fonts change label metrics; measure again.
  void _onFontsChanged() => setState(() => _metricsKey = null);

  Size _measure(String text, TextStyle? style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: _metricsKey!.$3,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final labels = widget.labels;
    final onAddShape = widget.onAddShape;
    final onRenameJoint = widget.onRenameJoint;
    final theme = Theme.of(context);
    final showLabels = controller.config.showToolbarLabels;
    final labelStyle = theme.textTheme.labelSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final key = (labelStyle, textScaler, Directionality.of(context));
    if (key != _metricsKey) {
      _metricsKey = key;
      _labelWidths.clear();
      _labelHeight = null;
    }

    ToolbarButton button(
      IconData icon,
      String tooltip,
      String label,
      VoidCallback? onPressed, {
      bool? selected,
    }) => ToolbarButton(
      icon: icon,
      tooltip: tooltip,
      label: label,
      showLabel: showLabels,
      selected: selected,
      onPressed: onPressed,
    );

    final jointTool = controller.tool == DrawingTool.joint;
    final create = [
      button(
        Icons.crop_square,
        labels.addSquare,
        labels.squareShort,
        () => onAddShape(ShapeType.square),
      ),
      button(
        Icons.rectangle_outlined,
        labels.addRectangle,
        labels.rectangleShort,
        () => onAddShape(ShapeType.rectangle),
      ),
      button(
        Icons.circle_outlined,
        labels.addCircle,
        labels.circleShort,
        () => onAddShape(ShapeType.circle),
      ),
      button(
        Icons.push_pin_outlined,
        labels.jointTool,
        labels.jointShort,
        () => controller.tool = jointTool
            ? DrawingTool.select
            : DrawingTool.joint,
        selected: jointTool,
      ),
      if (controller.config.gridSize != null)
        button(
          Icons.grid_4x4,
          controller.gridVisible ? labels.hideGrid : labels.showGrid,
          labels.gridShort,
          () => controller.gridVisible = !controller.gridVisible,
          selected: controller.gridVisible,
        ),
      button(
        Icons.undo,
        labels.undo,
        labels.undoShort,
        controller.canUndo ? controller.undo : null,
      ),
      button(
        Icons.redo,
        labels.redo,
        labels.redoShort,
        controller.canRedo ? controller.redo : null,
      ),
    ];

    final joint = controller.selectedJoint;
    final document = controller.document;
    final sizeButtons = {
      JointLabelSize.small: (
        Icons.text_decrease,
        labels.jointSizeSmall,
        labels.jointSizeSmallShort,
      ),
      JointLabelSize.medium: (
        Icons.text_fields,
        labels.jointSizeMedium,
        labels.jointSizeMediumShort,
      ),
      JointLabelSize.large: (
        Icons.text_increase,
        labels.jointSizeLarge,
        labels.jointSizeLargeShort,
      ),
    };
    final selection = [
      if (jointTool) ...[
        for (final MapEntry(key: size, value: (icon, tooltip, label))
            in sizeButtons.entries)
          button(
            icon,
            tooltip,
            label,
            () => controller.setJointLabelSize(size),
            selected: document.jointLabelSize == size,
          ),
        button(
          document.jointsVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          document.jointsVisible ? labels.hideJoints : labels.showJoints,
          document.jointsVisible
              ? labels.hideJointsShort
              : labels.showJointsShort,
          () => controller.setJointsVisible(!document.jointsVisible),
          selected: !document.jointsVisible,
        ),
      ],
      if (joint != null) ...[
        button(
          Icons.edit_outlined,
          labels.renameJoint,
          labels.renameShort,
          () => onRenameJoint(joint.id),
        ),
        button(
          Icons.delete_outline,
          labels.deleteJoint,
          labels.deleteShort,
          () => controller.removeJoint(joint.id),
        ),
      ],
      if (!jointTool &&
          (controller.selectionMode ||
              (joint == null && controller.selectedIds.isEmpty)))
        button(
          Icons.highlight_alt,
          labels.select,
          labels.selectShort,
          () => controller.selectionMode = !controller.selectionMode,
          selected: controller.selectionMode,
        ),
      if (controller.selectedIds.length > 1)
        controller.selectedGroup == null
            ? button(
                Icons.link,
                labels.group,
                labels.groupShort,
                controller.groupSelected,
              )
            : button(
                Icons.link_off,
                labels.ungroup,
                labels.ungroupShort,
                controller.ungroupSelected,
              ),
      if (controller.selectedIds.isNotEmpty) ...[
        // Only a single shape rotates (spec 05, MS-5).
        if (controller.selectedIds.length == 1)
          button(
            Icons.rotate_right,
            labels.rotate90,
            labels.rotateShort,
            () => controller.rotateSelectedBy(math.pi / 2),
          ),
        button(
          Icons.copy_outlined,
          labels.duplicate,
          labels.duplicateShort,
          controller.duplicateSelected,
        ),
        button(
          Icons.flip_to_front,
          labels.bringToFront,
          labels.frontShort,
          controller.bringToFront,
        ),
        button(
          Icons.flip_to_back,
          labels.sendToBack,
          labels.backShort,
          controller.sendToBack,
        ),
        button(
          Icons.delete_outline,
          labels.delete,
          labels.deleteShort,
          controller.deleteSelected,
        ),
      ],
    ];

    double textWidth(String text) => _labelWidths.putIfAbsent(
      text,
      () => _measure(text, labelStyle, textScaler).width,
    );

    double minWidth(List<ToolbarButton> buttons) => showLabels
        ? buttons.fold(
            _minButtonExtent,
            (w, b) => math.max(w, textWidth(b.label) + _labelPadding),
          )
        : _minButtonExtent;

    final labelHeight = showLabels
        ? _labelHeight ??= _measure('Ag', labelStyle, textScaler).height
        : 0.0;
    // Mirrors the content of [ToolbarButton]: the padded icon, then the
    // label under it.
    final rowHeight = math.max(
      _minButtonExtent,
      _iconSize +
          2 * _iconVerticalPadding +
          _rowVerticalSlack +
          (showLabels ? _labelGap + labelHeight : 0),
    );

    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: EditorToolbar.selectionBarKey,
              height: rowHeight,
              child: _ToolbarRow(
                buttons: selection,
                minButtonWidth: minWidth(selection),
              ),
            ),
            SizedBox(
              key: EditorToolbar.createBarKey,
              height: rowHeight,
              child: _ToolbarRow(
                buttons: create,
                minButtonWidth: minWidth(create),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One toolbar row: buttons share the width equally, never below
/// [minButtonWidth]; a row that does not fit scrolls horizontally instead
/// of wrapping (spec 03, TB-4).
class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({required this.buttons, required this.minButtonWidth});

  final List<ToolbarButton> buttons;
  final double minButtonWidth;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = buttons.length * minButtonWidth <= constraints.maxWidth;
        final width = fits
            ? constraints.maxWidth / buttons.length
            : minButtonWidth;
        final row = Row(
          children: [for (final b in buttons) SizedBox(width: width, child: b)],
        );
        return fits
            ? row
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              );
      },
    );
  }
}

/// A toolbar button: an icon over a short label, with a longer tooltip.
///
/// The button is one semantics node that is announced once, by its tooltip
/// (spec 03, LB-5).
class ToolbarButton extends StatelessWidget {
  /// Creates a toolbar button.
  const ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.onPressed,
    this.showLabel = true,
    this.selected,
  });

  /// Icon shown on the button.
  final IconData icon;

  /// Longer description shown as tooltip and announced by screen readers.
  final String tooltip;

  /// Short one-word label shown under the icon.
  final String label;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// Whether [label] is shown.
  final bool showLabel;

  /// For toggles, whether the toggle is on; null for plain actions.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final on = selected ?? false;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : on
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _minButtonExtent,
                minHeight: _minButtonExtent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: on ? scheme.secondaryContainer : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: _iconVerticalPadding,
                      ),
                      child: Icon(icon, size: _iconSize, color: color),
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: _labelGap),
                    ExcludeSemantics(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
