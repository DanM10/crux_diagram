import { forwardRef } from 'react';
import { Layer } from 'react-konva';
import { useStore } from 'zustand';
import { EditorProvider, useEditor, type DrawingEditorHandle, type EditorProviderProps } from './editor-context.js';
import { DrawingStage } from './render/DrawingStage.js';

export type DrawingEditorProps = Omit<EditorProviderProps, 'children'>;

/** Controlled drawing editor (REA-002). Interactions are added in later tasks. */
export const DrawingEditor = forwardRef<DrawingEditorHandle, DrawingEditorProps>(function DrawingEditor(props, ref) {
  return (
    <EditorProvider ref={ref} {...props}>
      <EditorCanvas />
    </EditorProvider>
  );
});

/** The editor's stage: the gesture preview while there is one, else the document. */
function EditorCanvas() {
  const editor = useEditor();
  const document = useStore(editor, (state) => state.preview ?? state.document);
  return (
    <DrawingStage document={document} listening>
      <Layer name="editor-ui" />
    </DrawingStage>
  );
}
