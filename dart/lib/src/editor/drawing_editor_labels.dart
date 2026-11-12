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
  });

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
}
