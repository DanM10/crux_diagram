import type { DrawingDocument } from '@diagrama-kit/core';
import { temporal } from 'zundo';
import { createStore } from 'zustand/vanilla';
import { DEFAULT_EDITOR_CONFIG } from './config.js';

/** View settings: never in history and never a document change (REA-017). */
export interface EditorView {
  readonly showGrid: boolean;
}

export interface EditorState {
  /** The committed document, the one `onChange` receives. */
  readonly document: DrawingDocument;
  /** The document shown during a continuous gesture, or `null` (REA-003). */
  readonly preview: DrawingDocument | null;
  readonly view: EditorView;
}

export interface EditorStoreOptions {
  /** Maximum number of undo entries (default 100). */
  readonly historyLimit?: number;
  /** Initial grid visibility (default false). */
  readonly showGrid?: boolean;
}

/**
 * The editor's state with a snapshot history (spec 05 section 4). Only the committed
 * document is recorded: a commit is one entry, previews and view changes are none.
 */
export function createEditorStore(initial: DrawingDocument, options: EditorStoreOptions = {}) {
  const store = createStore<EditorState>()(
    temporal(
      (): EditorState => ({ document: initial, preview: null, view: { showGrid: options.showGrid ?? DEFAULT_EDITOR_CONFIG.showGrid } }),
      {
        limit: options.historyLimit ?? DEFAULT_EDITOR_CONFIG.historyLimit,
        partialize: (state) => ({ document: state.document }),
        // A set that keeps the same document instance (a preview or a view change) is not an entry.
        equality: (past, current) => past.document === current.document,
      },
    ),
  );
  const history = () => store.temporal.getState();
  const dropPreview = () => {
    if (store.getState().preview) store.setState({ preview: null });
  };

  return {
    getState: store.getState,
    getInitialState: store.getInitialState,
    subscribe: store.subscribe,
    /** The committed document. */
    getDocument: () => store.getState().document,
    canUndo: () => history().pastStates.length > 0,
    canRedo: () => history().futureStates.length > 0,
    /** Commits `document` as one entry and ends any gesture; the same instance adds none. */
    commit(document: DrawingDocument) {
      store.setState({ document, preview: null });
    },
    /** Shows `document` during a gesture without committing it; `null` cancels the gesture. */
    preview(document: DrawingDocument | null) {
      store.setState({ preview: document });
    },
    undo() {
      dropPreview();
      history().undo();
    },
    redo() {
      dropPreview();
      history().redo();
    },
    /** Replaces the document and clears the history, adding no entry. */
    reset(document: DrawingDocument) {
      store.setState({ document, preview: null });
      history().clear();
    },
    setShowGrid(showGrid: boolean) {
      store.setState({ view: { ...store.getState().view, showGrid } });
    },
  };
}

export type EditorStore = ReturnType<typeof createEditorStore>;
