import { forwardRef } from 'react';
import { EditorProvider, type DrawingEditorHandle, type EditorProviderProps } from './editor-context.js';

export type DrawingEditorProps = Omit<EditorProviderProps, 'children'>;

/** Controlled drawing editor (REA-002). The canvas and its interactions are added in later tasks. */
export const DrawingEditor = forwardRef<DrawingEditorHandle, DrawingEditorProps>(function DrawingEditor(props, ref) {
  return <EditorProvider ref={ref} {...props} />;
});
