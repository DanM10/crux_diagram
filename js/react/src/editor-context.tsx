import type { DrawingDocument } from '@crux-diagram/core';
import { exportImage, type ExportImageOptions } from './export/export-image.js';
import { createContext, forwardRef, useContext, useEffect, useImperativeHandle, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { resolveEditorConfig, type DrawingEditorConfig, type DrawingEditorConfigInput } from './config.js';
import { resolveEditorLabels, type EditorLabels, type EditorLabelsInput } from './labels.js';
import { createEditorStore, type EditorStore } from './store.js';

/** Imperative API of the editor (REA-004). Members are added as their tasks land. */
export interface DrawingEditorHandle {
  undo(): void;
  redo(): void;
  readonly canUndo: boolean;
  readonly canRedo: boolean;
  /** The committed document (never a gesture preview). */
  getDocument(): DrawingDocument;
  /** Replaces the document and clears the history, without calling `onChange` (opening another drawing). */
  reset(document: DrawingDocument): void;
  /** Returns to the fitted view, 1× with no pan; not a document change (REA-016, REA-017). */
  fitToScreen(): void;
  /** Renders the committed document to a PNG or JPEG `Blob`, optionally saving it (REA-040 to REA-043). */
  exportImage(options: ExportImageOptions): Promise<Blob>;
}

export interface EditorProviderProps {
  /**
   * The document to show. A value the editor did not produce is applied as one undoable
   * change; a late echo of an emitted document is ignored (REA-007). To open another
   * drawing with an empty history, change the editor's `key` or call `reset`.
   */
  value: DrawingDocument;
  /** Receives a new document on every committed change (REA-002). */
  onChange: (document: DrawingDocument) => void;
  /** Receives the document during a continuous gesture, before the release commits it (REA-003). */
  onPreview?: (document: DrawingDocument) => void;
  config?: DrawingEditorConfigInput;
  /** Texts of the ready-made controls (REA-053); English by default. */
  labels?: EditorLabelsInput;
  children?: ReactNode;
}

interface EditorContextValue {
  readonly editor: EditorStore;
  readonly config: DrawingEditorConfig;
  readonly labels: EditorLabels;
}

const EditorContext = createContext<EditorContextValue | null>(null);

// useLayoutEffect warns during server rendering on React 18; nothing runs there anyway.
const useIsomorphicLayoutEffect = typeof window === 'undefined' ? useEffect : useLayoutEffect;

/** Owns the editor store and binds it to the controlled `value`/`onChange` pair. */
export const EditorProvider = forwardRef<DrawingEditorHandle, EditorProviderProps>(function EditorProvider(
  { value, onChange, onPreview, config: configInput, labels: labelsInput, children },
  ref,
) {
  const config = useMemo(() => resolveEditorConfig(configInput), [configInput]);
  const labels = useMemo(() => resolveEditorLabels(labelsInput), [labelsInput]);
  // Created once: the history limit and the initial grid visibility are read at mount.
  const [editor] = useState(() => createEditorStore(value, { historyLimit: config.historyLimit, showGrid: config.showGrid }));
  const latest = useRef({ onChange, onPreview });
  useIsomorphicLayoutEffect(() => {
    latest.current = { onChange, onPreview };
  });

  // Documents emitted since the parent last held the editor's document: a parent that
  // adopts late may still render one of them, and that echo must not undo newer commits.
  // Only the most recent ones are kept, so a parent that never adopts cannot grow it forever.
  const unadopted = useRef(new Set<DrawingDocument>());
  const maxUnadopted = config.historyLimit + 1;
  // Runs `change` without emitting: for the parent's own value and for `reset`.
  const quiet = useRef(false);
  const quietly = (change: () => void) => {
    quiet.current = true;
    try {
      change();
    } finally {
      quiet.current = false;
    }
  };

  // Every committed change made in the editor is emitted, including an undo back to the
  // parent's current value; previews go to onPreview.
  useEffect(
    () =>
      editor.subscribe((state, previous) => {
        if (state.document !== previous.document && !quiet.current) {
          const pending = unadopted.current;
          pending.delete(state.document);
          pending.add(state.document);
          for (const oldest of pending) {
            if (pending.size <= maxUnadopted) break;
            pending.delete(oldest);
          }
          latest.current.onChange(state.document);
        }
        if (state.preview && state.preview !== previous.preview) latest.current.onPreview?.(state.preview);
      }),
    [editor, maxUnadopted],
  );

  // REA-007: a new value never clears the history by itself.
  useEffect(() => {
    if (value === editor.getDocument()) {
      unadopted.current.clear();
      return;
    }
    if (unadopted.current.has(value)) return;
    unadopted.current.clear();
    quietly(() => editor.commit(value));
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
      fitToScreen: editor.fitToScreen,
      exportImage: (options: ExportImageOptions) => exportImage(editor.getDocument(), options, { maxPixels: config.exportMaxPixels }),
      reset(document: DrawingDocument) {
        quietly(() => editor.reset(document));
        unadopted.current.clear();
      },
    }),
    [editor, config],
  );

  const context = useMemo(() => ({ editor, config, labels }), [editor, config, labels]);
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

/** The texts of the enclosing editor's controls. */
export const useEditorLabels = (): EditorLabels => useEditorContext().labels;
