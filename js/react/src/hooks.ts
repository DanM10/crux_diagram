import { useSyncExternalStore } from 'react';
import type { EditorStore } from './store.js';

/** Whether there is something to undo or redo, kept up to date as the history changes. */
export function useHistoryAvailability(editor: EditorStore): { readonly canUndo: boolean; readonly canRedo: boolean } {
  const canUndo = useSyncExternalStore(editor.subscribeHistory, editor.canUndo, editor.canUndo);
  const canRedo = useSyncExternalStore(editor.subscribeHistory, editor.canRedo, editor.canRedo);
  return { canUndo, canRedo };
}
