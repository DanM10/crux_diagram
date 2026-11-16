import 'package:flutter/foundation.dart';

/// Every user-visible string in the editor, with English defaults.
///
/// Pass translated values to localize the editor without forking the
/// package.
@immutable
class DrawingEditorLabels {
  /// Creates labels; any omitted value keeps its English default.
  const DrawingEditorLabels({
    this.addSquare = 'Add square',
    this.addRectangle = 'Add rectangle',
    this.addCircle = 'Add circle',
    this.delete = 'Delete',
    this.duplicate = 'Duplicate',
    this.rotate90 = 'Rotate 90°',
    this.bringToFront = 'Bring to front',
    this.sendToBack = 'Send to back',
    this.undo = 'Undo',
    this.redo = 'Redo',
    this.done = 'Done',
    this.cancel = 'Cancel',
    this.discardChangesTitle = 'Discard changes?',
    this.discardChangesBody = 'Your drawing has unsaved changes.',
    this.discard = 'Discard',
    this.keepEditing = 'Keep editing',
    this.exportFailed = 'The drawing could not be exported.',
    this.jointTool = 'Joint tool',
    this.renameJoint = 'Rename joint',
    this.deleteJoint = 'Delete joint',
    this.jointNameHint = 'Joint name',
    this.jointNameSuggestions = 'Suggestions',
    this.ok = 'OK',
    this.squareShort = 'Square',
    this.rectangleShort = 'Rect',
    this.circleShort = 'Circle',
    this.jointShort = 'Joint',
    this.gridShort = 'Grid',
    this.undoShort = 'Undo',
    this.redoShort = 'Redo',
    this.rotateShort = 'Rotate',
    this.duplicateShort = 'Copy',
    this.frontShort = 'Front',
    this.backShort = 'Back',
    this.deleteShort = 'Delete',
    this.renameShort = 'Rename',
    this.jointSizeSmallShort = 'Small',
    this.jointSizeMediumShort = 'Medium',
    this.jointSizeLargeShort = 'Large',
    this.showJointsShort = 'Show',
    this.hideJointsShort = 'Hide',
    this.showGrid = 'Show grid',
    this.hideGrid = 'Hide grid',
    this.jointSizeSmall = 'Small joint labels',
    this.jointSizeMedium = 'Medium joint labels',
    this.jointSizeLarge = 'Large joint labels',
    this.showJoints = 'Show joints',
    this.hideJoints = 'Hide joints',
    this.fitToScreen = 'Fit to screen',
    this.jointModeHint = 'Tap a corner or edge point to add a joint',
    this.exitJointMode = 'Done adding joints',
    this.zoomPercent = _defaultZoomPercent,
    this.invalidDrawing = 'This drawing could not be opened.',
    this.close = 'Close',
    this.select = 'Select shapes',
    this.selectShort = 'Select',
    this.group = 'Group shapes',
    this.groupShort = 'Group',
    this.ungroup = 'Ungroup shapes',
    this.ungroupShort = 'Ungroup',
  });

  static String _defaultZoomPercent(int percent) => '$percent%';

  /// Palette button that adds a square.
  final String addSquare;

  /// Palette button that adds a rectangle.
  final String addRectangle;

  /// Palette button that adds a circle.
  final String addCircle;

  /// Deletes the selection.
  final String delete;

  /// Duplicates the selected shape.
  final String duplicate;

  /// Rotates the selected shape 90° clockwise.
  final String rotate90;

  /// Moves the selected shape to the top of the stack.
  final String bringToFront;

  /// Moves the selected shape to the bottom of the stack.
  final String sendToBack;

  /// Undoes the last edit.
  final String undo;

  /// Redoes the last undone edit.
  final String redo;

  /// Confirms the drawing and closes the editor page.
  final String done;

  /// Closes the editor page without a result.
  final String cancel;

  /// Title of the dialog shown when leaving with unsaved changes.
  final String discardChangesTitle;

  /// Body of the dialog shown when leaving with unsaved changes.
  final String discardChangesBody;

  /// Dialog action that leaves and drops the changes.
  final String discard;

  /// Dialog action that stays in the editor.
  final String keepEditing;

  /// Message shown when confirming fails because the export failed.
  final String exportFailed;

  /// Tooltip of the Joint tool toggle.
  final String jointTool;

  /// Tooltip of the action that renames the selected joint.
  final String renameJoint;

  /// Tooltip of the action that deletes the selected joint.
  final String deleteJoint;

  /// Hint of the joint name field.
  final String jointNameHint;

  /// Heading above the suggested joint names in the name dialog.
  final String jointNameSuggestions;

  /// Confirm button of the joint name editor.
  final String ok;

  /// Short label of the add-square button.
  final String squareShort;

  /// Short label of the add-rectangle button.
  final String rectangleShort;

  /// Short label of the add-circle button.
  final String circleShort;

  /// Short label of the Joint tool toggle.
  final String jointShort;

  /// Short label of the grid toggle.
  final String gridShort;

  /// Short label of the undo button.
  final String undoShort;

  /// Short label of the redo button.
  final String redoShort;

  /// Short label of the rotate-90° button.
  final String rotateShort;

  /// Short label of the duplicate button.
  final String duplicateShort;

  /// Short label of the bring-to-front button.
  final String frontShort;

  /// Short label of the send-to-back button.
  final String backShort;

  /// Short label of the delete buttons.
  final String deleteShort;

  /// Short label of the rename-joint button.
  final String renameShort;

  /// Short label of the small joint label size button (spec 04, JD-1).
  final String jointSizeSmallShort;

  /// Short label of the medium joint label size button.
  final String jointSizeMediumShort;

  /// Short label of the large joint label size button.
  final String jointSizeLargeShort;

  /// Short label of the joint visibility button while joints are hidden.
  final String showJointsShort;

  /// Short label of the joint visibility button while joints are shown.
  final String hideJointsShort;

  /// Tooltip of the grid toggle while the grid is hidden.
  final String showGrid;

  /// Tooltip of the grid toggle while the grid is shown.
  final String hideGrid;

  /// Tooltip of the small joint label size button (spec 04, JD-1).
  final String jointSizeSmall;

  /// Tooltip of the medium joint label size button.
  final String jointSizeMedium;

  /// Tooltip of the large joint label size button.
  final String jointSizeLarge;

  /// Tooltip of the joint visibility button while joints are hidden.
  final String showJoints;

  /// Tooltip of the joint visibility button while joints are shown.
  final String hideJoints;

  /// Button that returns the view to zoom 1× with no pan.
  final String fitToScreen;

  /// Hint shown while the Joint tool is active.
  final String jointModeHint;

  /// Button of the joint hint that switches back to the select tool.
  final String exitJointMode;

  /// Formats the zoom readout from a whole percentage, such as `250%`.
  ///
  /// Pass a static or top-level function to keep the labels `const`.
  final String Function(int percent) zoomPercent;

  /// Message shown by `DrawingEditorPage` when its initial JSON cannot be
  /// opened (spec 05, JX-2).
  final String invalidDrawing;

  /// Button under [invalidDrawing] that closes the page without a result.
  final String close;

  /// Tooltip of the toggle that enters and leaves selection mode
  /// (spec 05, MS-1).
  final String select;

  /// Short label of the selection mode toggle.
  final String selectShort;

  /// Tooltip of the action that groups the selected shapes (spec 05, MS-6).
  final String group;

  /// Short label of the group button.
  final String groupShort;

  /// Tooltip of the action that ungroups the selected group.
  final String ungroup;

  /// Short label of the ungroup button.
  final String ungroupShort;
}
