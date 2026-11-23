// Public API of @crux-diagram/react (spec 05). Nothing here may touch `window` at
// import time (REA-054).
export { DrawingEditor, type DrawingEditorProps } from './DrawingEditor.js';
export { DrawingViewer, type DrawingViewerProps } from './DrawingViewer.js';
export { Toolbar } from './Toolbar.js';
export { JointDisplayBar } from './JointDisplayBar.js';
export { DEFAULT_EDITOR_LABELS, type EditorLabels, type EditorLabelsInput } from './labels.js';
export type { DrawingEditorHandle } from './editor-context.js';
export type { ExportImageOptions } from './export/export-image.js';
export {
  DEFAULT_EDITOR_CONFIG,
  resolveEditorConfig,
  type DrawingEditorConfig,
  type DrawingEditorConfigInput,
  type ShapeStyle,
} from './config.js';
export {
  VersionHistory,
  DEFAULT_VERSION_HISTORY_LABELS,
  type VersionEntry,
  type VersionHistoryLabels,
  type VersionHistoryProps,
} from './VersionHistory.js';
