// Public API of @diagrama-kit/react (spec 05). Nothing here may touch `window` at
// import time (REA-054).
export { DrawingEditor, type DrawingEditorProps } from './DrawingEditor.js';
export type { DrawingEditorHandle } from './editor-context.js';
export {
  DEFAULT_EDITOR_CONFIG,
  resolveEditorConfig,
  type DrawingEditorConfig,
  type DrawingEditorConfigInput,
  type ShapeStyle,
} from './config.js';
