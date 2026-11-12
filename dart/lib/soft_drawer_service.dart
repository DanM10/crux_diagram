/// A Flutter 2D shape editor with snapping, rotation and anchor-based joint
/// arrows.
///
/// Build drawings from basic shapes and export them as JPEG plus a JSON
/// document that can be reopened later.
library;

export 'src/model/drawing_document.dart' show DrawingDocument;
export 'src/model/drawing_format_exception.dart' show DrawingFormatException;
export 'src/model/shape_element.dart' show ShapeElement;
export 'src/model/shape_type.dart' show ShapeType;
export 'src/editor/drawing_editor_config.dart' show DrawingEditorConfig;
export 'src/editor/drawing_editor_controller.dart' show DrawingEditorController;
export 'src/editor/drawing_editor.dart' show DrawingEditor;
export 'src/editor/drawing_editor_labels.dart' show DrawingEditorLabels;
