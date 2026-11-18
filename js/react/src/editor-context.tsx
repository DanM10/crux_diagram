import type { DrawingDocument } from '@diagrama-kit/core';
import { createContext, forwardRef, useContext, useEffect, useImperativeHandle, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { resolveEditorConfig, type DrawingEditorConfig, type DrawingEditorConfigInput } from './config.js';
import { createEditorStore, type EditorStore } from './store.js';

/** Imperative API of the editor (REA-004). Members are added as their tasks land. */
export interface DrawingEditorHandle {
  undo(): void;
  redo(): void;
  readonly canUndo: boolean;
  readonly canRedo: boolean;
  /** The committed document (never a gesture preview). */
  getDocument(): DrawingDocument;
}

export interface EditorProviderProps {
  /** The document to show. A value other than the last one emitted replaces the document and clears history. */
  value: DrawingDocument;
  /** Receives a new document on every committed change (REA-002). */
  onChange: (document: DrawingDocument) => void;
  /** Receives the document during a continuous gesture, before the release commits it (REA-003). */
  onPreview?: (document: DrawingDocument) => void;
  config?: DrawingEditorConfigInput;
  children?: ReactNode;
}

interface EditorContextValue {
  readonly editor: EditorStore;
  readonly config: DrawingEditorConfig;
}

const EditorContext = createContext<EditorContextValue | null>(null);

// useLayoutEffect warns during server rendering on React 18; nothing runs there anyway.
const useIsomorphicLayoutEffect = typeof window === 'undefined' ? useEffect : useLayoutEffect;

/** Owns the editor store and binds it to the controlled `value`/`onChange` pair. */
export const EditorProvider = forwardRef<DrawingEditorHandle, EditorProviderProps>(function EditorProvider(
  { value, onChange, onPreview, config: configInput, children },
  ref,
) {
  const config = useMemo(() => resolveEditorConfig(configInput), [configInput]);
  // Created once: the history limit and the initial grid visibility are read at mount.
  const [editor] = useState(() => createEditorStore(value, { historyLimit: config.historyLimit, showGrid: config.showGrid }));
  const latest = useRef({ value, onChange, onPreview });
  useIsomorphicLayoutEffect(() => {
    latest.current = { value, onChange, onPreview };
  });

  // A committed document the parent does not already hold is emitted; previews go to onPreview.
  useEffect(
    () =>
      editor.subscribe((state, previous) => {
        if (state.document !== previous.document && state.document !== latest.current.value) latest.current.onChange(state.document);
        if (state.preview && state.preview !== previous.preview) latest.current.onPreview?.(state.preview);
      }),
    [editor],
  );

  // A value that is not the current document comes from outside the editor (for example a load).
  useEffect(() => {
    if (value !== editor.getDocument()) editor.reset(value);
  }, [editor, value]);

  useImperativeHandle(
    ref,
    () => ({
      undo: editor.undo,
      redo: editor.redo,
      get canUndo() {
        return editor.canUndo();
      },
      get canRedo() {
        return editor.canRedo();
      },
      getDocument: editor.getDocument,
    }),
    [editor],
  );

  const context = useMemo(() => ({ editor, config }), [editor, config]);
  return <EditorContext.Provider value={context}>{children}</EditorContext.Provider>;
});

function useEditorContext(): EditorContextValue {
  const context = useContext(EditorContext);
  if (!context) throw new Error('This component must be rendered inside a DrawingEditor');
  return context;
}

/** The store of the enclosing editor. */
export const useEditor = (): EditorStore => useEditorContext().editor;

/** The resolved config of the enclosing editor. */
export const useEditorConfig = (): DrawingEditorConfig => useEditorContext().config;
