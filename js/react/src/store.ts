import { FITTED_ZOOM, withGroupMates, type DrawingDocument, type ViewportZoom } from '@diagrama-kit/core';
import { temporal } from 'zundo';
import { createStore } from 'zustand/vanilla';
import { DEFAULT_EDITOR_CONFIG } from './config.js';

/** View settings: never in history and never a document change (REA-017). */
export interface EditorView {
  readonly showGrid: boolean;
  /** Zoom and pan on top of the fitted view; the stage clamps it to the canvas (REA-016). */
  readonly zoom: ViewportZoom;
}

export interface EditorState {
  /** The committed document, the one `onChange` receives. */
  readonly document: DrawingDocument;
  /** The document shown during a continuous gesture, or `null` (REA-003). */
  readonly preview: DrawingDocument | null;
  readonly view: EditorView;
  /**
   * Ids of the selected shapes in document z-order, always with whole groups (MS-6).
   * Never in history: selecting adds no entry (REA-018).
   */
  readonly selection: readonly string[];
  /** Whether taps toggle shapes and empty-canvas drags draw a selection rectangle (MS-1, MS-3). */
  readonly selectionMode: boolean;
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
      (): EditorState => ({
        document: initial,
        preview: null,
        view: { showGrid: options.showGrid ?? DEFAULT_EDITOR_CONFIG.showGrid, zoom: FITTED_ZOOM },
        selection: [],
        selectionMode: false,
      }),
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
  const sameIds = (a: readonly string[], b: readonly string[]) => a.length === b.length && a.every((id, i) => id === b[i]);
  const setSelection = (selection: readonly string[]) => {
    if (!sameIds(selection, store.getState().selection)) store.setState({ selection });
  };
  // Flutter `_dropStaleSelection`: after the document changes, keep only the shapes that
  // still exist, with their current groups.
  const dropStaleSelection = () => {
    const { document, selection } = store.getState();
    const existing = new Set(document.shapes.map((s) => s.id));
    setSelection(withGroupMates(document, selection.filter((id) => existing.has(id))));
  };

  return {
    getState: store.getState,
    getInitialState: store.getInitialState,
    subscribe: store.subscribe,
    /** The committed document. */
    getDocument: () => store.getState().document,
    canUndo: () => history().pastStates.length > 0,
    canRedo: () => history().futureStates.length > 0,
    /**
     * Commits `document` as one entry and ends any gesture; the same instance adds none.
     * With `selection`, the selection becomes those shapes (and their groups) in the same update.
     */
    commit(document: DrawingDocument, selection?: readonly string[]) {
      // Resolve the selection first: an unknown id throws before anything is recorded.
      const next = selection ? withGroupMates(document, selection) : null;
      store.setState({ document, preview: null });
      if (next) setSelection(next);
      else dropStaleSelection();
    },
    /** Shows `document` during a gesture without committing it; `null` cancels the gesture. */
    preview(document: DrawingDocument | null) {
      store.setState({ preview: document });
    },
    undo() {
      dropPreview();
      history().undo();
      dropStaleSelection();
    },
    redo() {
      dropPreview();
      history().redo();
      dropStaleSelection();
    },
    /** Replaces the document and clears the history, adding no entry. */
    reset(document: DrawingDocument) {
      store.setState({ document, preview: null });
      history().clear();
      dropStaleSelection();
    },
    /** Selects the shape with `id` and the rest of its group, or clears the selection with `null` (Flutter `select`). */
    select(id: string | null) {
      setSelection(id === null ? [] : withGroupMates(store.getState().document, [id]));
    },
    /** Adds the shape with `id` and its group to the selection, or removes them when it is selected (MS-1, MS-6). */
    toggleSelected(id: string) {
      const { document, selection } = store.getState();
      const members = new Set(withGroupMates(document, [id]));
      const next = selection.includes(id)
        ? selection.filter((s) => !members.has(s))
        : withGroupMates(document, [...selection, ...members]);
      setSelection(next);
    },
    /** Adds the shapes with `ids`, and their groups, to the selection (MS-3). */
    selectAll(ids: readonly string[]) {
      const { document, selection } = store.getState();
      setSelection(withGroupMates(document, [...selection, ...ids]));
    },
    /** Enters or leaves selection mode; leaving it keeps the selection (MS-8). */
    setSelectionMode(selectionMode: boolean) {
      if (store.getState().selectionMode !== selectionMode) store.setState({ selectionMode });
    },
    /** Sets zoom and pan: a view change, never a history entry (REA-017). */
    setZoom(zoom: ViewportZoom) {
      store.setState({ view: { ...store.getState().view, zoom } });
    },
    /** Returns to the fitted view: 1× with no pan (REA-004). */
    fitToScreen() {
      store.setState({ view: { ...store.getState().view, zoom: FITTED_ZOOM } });
    },
    setShowGrid(showGrid: boolean) {
      store.setState({ view: { ...store.getState().view, showGrid } });
    },
  };
}

export type EditorStore = ReturnType<typeof createEditorStore>;
