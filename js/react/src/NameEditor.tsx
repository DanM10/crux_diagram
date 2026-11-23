// The joint name editor: an HTML input over the label, in the label font (REA-021, REA-031).

import { anchorPositionOf, DEFAULT_JOINT_STYLE, labelFontSize, toScreen, type CanvasViewport, type DrawingDocument } from '@crux-diagram/core';
import { useState, type KeyboardEvent } from 'react';
import { LABEL_FONT_FAMILY } from './render/scene.js';
import type { JointNaming } from './store.js';

export interface NameEditorProps {
  /** The document that shows the joint (a new joint is only in the preview). */
  readonly document: DrawingDocument;
  readonly naming: JointNaming;
  readonly viewport: CanvasViewport;
  /** Names offered as buttons (config `jointNameSuggestions`). */
  readonly suggestions: readonly string[];
  readonly onConfirm: (name: string) => void;
  readonly onCancel: () => void;
}

/** Names from `suggestions` that no other joint uses; the joint being named does not count (NS-4). */
export function freeSuggestions(document: DrawingDocument, jointId: string, suggestions: readonly string[]): string[] {
  const used = new Set(document.joints.filter((j) => j.id !== jointId).map((j) => j.name));
  return suggestions.filter((name) => !used.has(name));
}

export function NameEditor({ document, naming, viewport, suggestions, onConfirm, onCancel }: NameEditorProps) {
  const joint = document.joints.find((j) => j.id === naming.jointId);
  const shape = joint && document.shapes.find((s) => s.id === joint.shapeId);
  const anchor = shape && joint ? anchorPositionOf(shape, joint.anchorId) : null;
  const [text, setText] = useState(joint?.name ?? '');
  if (!joint || !anchor) return null;
  const center = toScreen(viewport, { x: anchor.x + joint.labelOffset.dx, y: anchor.y + joint.labelOffset.dy });
  const fontSize = labelFontSize(DEFAULT_JOINT_STYLE, document.jointDisplay.labelSize) * viewport.scale;
  const free = freeSuggestions(document, joint.id, suggestions);
  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    // The editor's own keys: they must not reach the editor's shortcuts.
    event.stopPropagation();
    if (event.key === 'Enter') onConfirm(text);
    else if (event.key === 'Escape') onCancel();
  };
  return (
    <div style={{ position: 'absolute', left: center.x, top: center.y, transform: 'translate(-50%, -50%)', textAlign: 'center' }}>
      <input
        type="text"
        aria-label="Joint name"
        autoFocus
        value={text}
        onChange={(event) => setText(event.target.value)}
        onFocus={(event) => event.target.select()}
        onBlur={() => onConfirm(text)}
        onKeyDown={onKeyDown}
        style={{ width: '8em', textAlign: 'center', fontFamily: `${LABEL_FONT_FAMILY}, sans-serif`, fontWeight: 'bold', fontSize }}
      />
      {free.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 4, marginTop: 4 }}>
          {free.map((name) => (
            <button
              key={name}
              type="button"
              // Keep the focus in the input so that the click, not a blur, confirms.
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => onConfirm(name)}
            >
              {name}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
