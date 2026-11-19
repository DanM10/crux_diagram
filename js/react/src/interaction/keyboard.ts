// Editor keyboard shortcuts (REA-014, REA-015, REA-018). Flutter has none; these follow
// the REA-018 assumption: they act only while the editor has the focus and never while
// a text field has it.

import { duplicateShapes, moveShape, removeShape } from '@diagrama-kit/core';
import type { EditorStore } from '../store.js';

/** Arrow-key move, in canvas units; `Shift` uses the large step (REA-015). */
export const NUDGE_STEP = 1;
export const NUDGE_STEP_LARGE = 10;

export type EditorCommand =
  | { readonly type: 'delete' }
  | { readonly type: 'undo' }
  | { readonly type: 'redo' }
  | { readonly type: 'duplicate' }
  | { readonly type: 'nudge'; readonly dx: number; readonly dy: number };

/** The modifier and key fields of a `KeyboardEvent`. */
export interface KeyInput {
  readonly key: string;
  readonly ctrlKey: boolean;
  readonly metaKey: boolean;
  readonly shiftKey: boolean;
  readonly altKey: boolean;
}

const ARROWS: Readonly<Record<string, readonly [number, number]>> = {
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
};

/** The command bound to a key press, or `null` when the key is not a shortcut. */
export function commandForKey(event: KeyInput): EditorCommand | null {
  if (event.altKey) return null;
  const command = event.ctrlKey || event.metaKey;
  const key = event.key.toLowerCase();
  if (command) {
    if (key === 'z') return { type: event.shiftKey ? 'redo' : 'undo' };
    if (key === 'd' && !event.shiftKey) return { type: 'duplicate' };
    return null;
  }
  if (event.key === 'Delete' || event.key === 'Backspace') return { type: 'delete' };
  const arrow = ARROWS[event.key];
  if (!arrow) return null;
  const step = event.shiftKey ? NUDGE_STEP_LARGE : NUDGE_STEP;
  return { type: 'nudge', dx: arrow[0] * step, dy: arrow[1] * step };
}

/** Whether key presses on `target` belong to a text field rather than to the editor. */
export function isTextEntry(target: EventTarget | null): boolean {
  if (!target || typeof (target as Element).tagName !== 'string') return false;
  const element = target as HTMLElement;
  const tag = element.tagName.toLowerCase();
  return tag === 'input' || tag === 'textarea' || tag === 'select' || element.isContentEditable === true || element.getAttribute('contenteditable') === 'true';
}

/**
 * Runs `command` on the committed document. Each change is one history entry: delete
 * removes the selected shapes with their joints (REC-071) and clears the selection;
 * duplicate copies them as FR-20 does and selects the copies; nudge moves them without
 * grid snapping, every center kept inside the canvas (FR-10). Without a selection, or
 * when nothing would change, it does nothing.
 */
export function runCommand(editor: EditorStore, command: EditorCommand): void {
  if (command.type === 'undo') return editor.undo();
  if (command.type === 'redo') return editor.redo();
  const { document, selection } = editor.getState();
  if (selection.length === 0) return;
  switch (command.type) {
    case 'delete':
      editor.commit(removeShape(document, selection), []);
      return;
    case 'duplicate': {
      const next = duplicateShapes(document, selection);
      editor.commit(next, next.shapes.slice(-selection.length).map((s) => s.id));
      return;
    }
    case 'nudge': {
      const next = moveShape(document, selection, { dx: command.dx, dy: command.dy });
      if (next !== document) editor.commit(next);
    }
  }
}
