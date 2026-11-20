// The joint tool on the store: create, select, name and delete joints
// (REA-020, REA-021, REA-025; Flutter JT-1 to JT-4, NM-1, NM-2, DL-1, DL-3, NS-4).
import { setJointDisplay } from '@diagrama-kit/core';
import { describe, expect, it } from 'vitest';
import { beginRename, cancelNaming, confirmNaming, jointToolTap } from '../src/interaction/joints.js';
import { runCommand } from '../src/interaction/keyboard.js';
import { createEditorStore } from '../src/store.js';
import { docOf, joint, rect } from './support/docs.js';

const options = { scale: 1, namePrefix: 'J', nameMaxLength: 12 };
// Rectangle `a` is 100 × 60 at (200, 200): its `tl` anchor is at (150, 170).
const TL = { x: 150, y: 170 };
const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)]);

describe('tool, joint selection and naming are view state', () => {
  it('start with the select tool, no joint selected and no name editor', () => {
    const editor = createEditorStore(doc);
    expect(editor.getState().tool).toBe('select');
    expect(editor.getState().selectedJoint).toBeNull();
    expect(editor.getState().naming).toBeNull();
  });

  it('changing the tool adds no history entry', () => {
    const editor = createEditorStore(doc);
    editor.setTool('joint');
    expect(editor.getState().tool).toBe('joint');
    expect(editor.canUndo()).toBe(false);
  });

  it('selecting a joint clears the shape selection and selecting a shape clears the joint', () => {
    const withJoint = docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] });
    const editor = createEditorStore(withJoint);
    editor.select('a');
    editor.selectJoint('j1');
    expect(editor.getState().selection).toEqual([]);
    expect(editor.getState().selectedJoint).toBe('j1');
    editor.select('a');
    expect(editor.getState().selectedJoint).toBeNull();
  });

  it('a selected joint that stops existing is dropped by commit and by undo', () => {
    const withJoint = docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] });
    const editor = createEditorStore(withJoint);
    editor.selectJoint('j1');
    editor.commit({ ...withJoint, joints: [] });
    expect(editor.getState().selectedJoint).toBeNull();
    editor.selectJoint(null);
    editor.undo();
    editor.selectJoint('j1');
    editor.redo();
    expect(editor.getState().selectedJoint).toBeNull();
  });
});

describe('REA-020 tapping an anchor with the joint tool', () => {
  it('a free anchor creates a previewed joint with the next name, selects it and opens the name editor', () => {
    const editor = createEditorStore(doc);
    jointToolTap(editor, TL, options);
    const { preview, naming, selectedJoint } = editor.getState();
    expect(preview?.joints).toHaveLength(1);
    expect(preview?.joints[0]).toMatchObject({ shapeId: 'a', anchorId: 'tl', name: 'J1' });
    expect(naming).toEqual({ jointId: preview!.joints[0]!.id, isNew: true });
    expect(selectedJoint).toBe(preview!.joints[0]!.id);
    expect(editor.getDocument()).toBe(doc);
    expect(editor.canUndo()).toBe(false);
  });

  it('uses the configured prefix and the highest suffix in use', () => {
    const editor = createEditorStore(docOf([rect('a', 200, 200)], { joints: [{ ...joint('j1', 'a'), anchorId: 'br', name: 'P7' }] }));
    jointToolTap(editor, TL, { ...options, namePrefix: 'P' });
    expect(editor.getState().preview!.joints.at(-1)!.name).toBe('P8');
  });

  it('confirming a name commits the joint: creating and naming is one history entry (DL-3)', () => {
    const editor = createEditorStore(doc);
    jointToolTap(editor, TL, options);
    confirmNaming(editor, '  Knee ', options.nameMaxLength);
    expect(editor.getDocument().joints.map((j) => j.name)).toEqual(['Knee']);
    expect(editor.getState().preview).toBeNull();
    expect(editor.getState().naming).toBeNull();
    expect(editor.getState().selectedJoint).toBe(editor.getDocument().joints[0]!.id);
    editor.undo();
    expect(editor.getDocument().joints).toEqual([]);
    expect(editor.canUndo()).toBe(false);
  });

  it('an empty name cancels a new joint (NM-1)', () => {
    const editor = createEditorStore(doc);
    jointToolTap(editor, TL, options);
    confirmNaming(editor, '   ', options.nameMaxLength);
    expect(editor.getDocument()).toBe(doc);
    expect(editor.getState()).toMatchObject({ preview: null, naming: null, selectedJoint: null });
    expect(editor.canUndo()).toBe(false);
  });

  it('cancelling the editor drops the new joint and keeps hidden joints hidden', () => {
    const hidden = setJointDisplay(doc, { visible: false });
    const editor = createEditorStore(hidden);
    jointToolTap(editor, TL, options);
    expect(editor.getState().preview!.jointDisplay.visible).toBe(true);
    cancelNaming(editor);
    expect(editor.getDocument()).toBe(hidden);
    expect(editor.getState().preview).toBeNull();
    expect(editor.getState().selectedJoint).toBeNull();
  });

  it('undo while naming closes the editor', () => {
    const editor = createEditorStore(doc);
    editor.commit({ ...doc, shapes: [...doc.shapes] });
    jointToolTap(editor, TL, options);
    editor.undo();
    expect(editor.getState()).toMatchObject({ preview: null, naming: null, selectedJoint: null });
  });
});

describe('REA-020 an anchor that already has a joint', () => {
  const withJoint = docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] });

  it('is selected, with no duplicate and no name editor (JT-3)', () => {
    const editor = createEditorStore(withJoint);
    jointToolTap(editor, TL, options);
    expect(editor.getState()).toMatchObject({ selectedJoint: 'j1', naming: null, preview: null });
    expect(editor.getDocument()).toBe(withJoint);
  });

  it('with the joints hidden, shows them again in one history entry (REA-025)', () => {
    const hidden = setJointDisplay(withJoint, { visible: false });
    const editor = createEditorStore(hidden);
    jointToolTap(editor, TL, options);
    expect(editor.getDocument().jointDisplay.visible).toBe(true);
    expect(editor.getState().selectedJoint).toBe('j1');
    editor.undo();
    expect(editor.getDocument()).toBe(hidden);
  });
});

describe('REA-020 picking the anchor', () => {
  it('the hit radius is 22 screen pixels', () => {
    const editor = createEditorStore(doc);
    jointToolTap(editor, { x: TL.x + 23, y: TL.y }, options);
    expect(editor.getState().preview).toBeNull();
    jointToolTap(editor, { x: TL.x + 10, y: TL.y }, { ...options, scale: 2 }); // 20 screen px
    expect(editor.getState().preview).not.toBeNull();
  });

  it('with anchors of two shapes at the same distance, the topmost shape wins (JT-4)', () => {
    const editor = createEditorStore(docOf([rect('under', 200, 200), rect('over', 200, 200)]));
    jointToolTap(editor, TL, options);
    expect(editor.getState().preview!.joints[0]!.shapeId).toBe('over');
  });

  it('tapping empty canvas clears the joint selection', () => {
    const withJoint = docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] });
    const editor = createEditorStore(withJoint);
    editor.selectJoint('j1');
    jointToolTap(editor, { x: 900, y: 700 }, options);
    expect(editor.getState().selectedJoint).toBeNull();
    expect(editor.getState().preview).toBeNull();
  });
});

describe('REA-021 renaming a joint (NM-1, NM-2)', () => {
  const withJoint = docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] });

  it('a new name is one history entry', () => {
    const editor = createEditorStore(withJoint);
    beginRename(editor, 'j1');
    expect(editor.getState().naming).toEqual({ jointId: 'j1', isNew: false });
    confirmNaming(editor, 'Elbow', 12);
    expect(editor.getDocument().joints[0]!.name).toBe('Elbow');
    expect(editor.getState().naming).toBeNull();
    editor.undo();
    expect(editor.getDocument()).toBe(withJoint);
  });

  it('an empty name keeps the old one and adds no entry', () => {
    const editor = createEditorStore(withJoint);
    beginRename(editor, 'j1');
    confirmNaming(editor, ' ', 12);
    expect(editor.getDocument()).toBe(withJoint);
    expect(editor.getState().naming).toBeNull();
    expect(editor.canUndo()).toBe(false);
  });

  it('keeps at most `nameMaxLength` characters', () => {
    const editor = createEditorStore(withJoint);
    beginRename(editor, 'j1');
    confirmNaming(editor, 'abcdefghij', 4);
    expect(editor.getDocument().joints[0]!.name).toBe('abcd');
  });
});

describe('DL-1 deleting the selected joint', () => {
  const withJoint = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a')] });

  it('Delete removes the joint in one history entry and keeps the shapes', () => {
    const editor = createEditorStore(withJoint);
    editor.selectJoint('j1');
    runCommand(editor, { type: 'delete' });
    expect(editor.getDocument().joints).toEqual([]);
    expect(editor.getDocument().shapes).toHaveLength(2);
    expect(editor.getState().selectedJoint).toBeNull();
    editor.undo();
    expect(editor.getDocument()).toBe(withJoint);
  });

  it('with shapes selected, Delete still deletes the shapes with their joints (DL-2)', () => {
    const editor = createEditorStore(withJoint);
    editor.select('a');
    runCommand(editor, { type: 'delete' });
    expect(editor.getDocument().shapes.map((s) => s.id)).toEqual(['b']);
    expect(editor.getDocument().joints).toEqual([]);
  });
});
