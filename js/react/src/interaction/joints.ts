// The joint tool and the name editor, as store operations (REA-020, REA-021, REA-025;
// Flutter JT-1 to JT-4, NM-1, NM-2, DL-3).

import { addJoint, normalizeJointName, pickAnchor, renameJoint, setJointDisplay, type Point } from '@diagrama-kit/core';
import type { EditorStore } from '../store.js';
import { labelAt, type LabelRect } from './gestures.js';

/** Hit radius of an anchor, in screen pixels (JT-2). */
export const ANCHOR_HIT_RADIUS = 22;
/** Anchors whose distance differs by less than this, in screen pixels, are tied: the topmost shape wins (JT-4). */
export const ANCHOR_TIE_TOLERANCE = 2;
/** Radius of an anchor dot, in screen pixels (JT-1). */
export const ANCHOR_VISUAL_RADIUS = 5;

export interface JointToolOptions {
  /** Screen pixels per canvas unit. */
  readonly scale: number;
  readonly namePrefix: string;
  readonly nameMaxLength: number;
  /** The joint labels as drawn: tapping one selects its joint before any anchor is tried. */
  readonly labels?: readonly LabelRect[];
}

/**
 * A tap with the joint tool at canvas `point`. A free anchor gets a new joint, shown as a
 * preview until its name is confirmed so that creating and naming is one history entry
 * (DL-3); an anchor with a joint selects it, showing hidden joints again (REA-025); empty
 * canvas clears the joint selection.
 */
export function jointToolTap(editor: EditorStore, point: Point, { scale, namePrefix, nameMaxLength, labels }: JointToolOptions): void {
  const labeled = labels && labelAt(labels, point);
  if (labeled) return editor.selectJoint(labeled);
  const document = editor.getDocument();
  const hit = pickAnchor(document.shapes, point, {
    radius: ANCHOR_HIT_RADIUS / scale,
    tieTolerance: ANCHOR_TIE_TOLERANCE / scale,
  });
  if (!hit) return editor.selectJoint(null);
  const existing = document.joints.find((j) => j.shapeId === hit.shapeId && j.anchorId === hit.anchorId);
  if (existing) {
    if (!document.jointDisplay.visible) editor.commit(setJointDisplay(document, { visible: true }));
    return editor.selectJoint(existing.id);
  }
  const next = addJoint(document, { ...hit, namePrefix, maxNameLength: nameMaxLength });
  const created = next.joints[next.joints.length - 1]!;
  editor.preview(next);
  editor.selectJoint(created.id);
  editor.setNaming({ jointId: created.id, isNew: true });
}

/** Opens the name editor for an existing joint (NM-2). */
export function beginRename(editor: EditorStore, jointId: string): void {
  editor.setNaming({ jointId, isNew: false });
}

/**
 * Confirms the name editor with `raw`, trimmed and cut to `nameMaxLength` (NM-1). A new joint
 * is committed with its name; an empty name cancels it. An existing joint is renamed, or
 * keeps its name when `raw` is empty.
 */
export function confirmNaming(editor: EditorStore, raw: string, nameMaxLength: number): void {
  const { naming, preview } = editor.getState();
  if (!naming) return;
  const name = normalizeJointName(raw, nameMaxLength);
  if (naming.isNew) {
    if (!name || !preview) return cancelNaming(editor);
    editor.setNaming(null);
    editor.commit(renameJoint(preview, naming.jointId, name, nameMaxLength));
    return;
  }
  editor.setNaming(null);
  if (name) editor.commit(renameJoint(editor.getDocument(), naming.jointId, name, nameMaxLength));
}

/** Closes the name editor without a change; a joint that was being created is dropped. */
export function cancelNaming(editor: EditorStore): void {
  const { naming } = editor.getState();
  if (!naming) return;
  editor.setNaming(null);
  if (naming.isNew) {
    editor.preview(null);
    editor.selectJoint(null);
  }
}
